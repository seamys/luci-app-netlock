#!/bin/sh
# Test: Firewall rule generation (nft_block / nft_unblock)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/framework.sh"
. "${SCRIPT_DIR}/mocks.sh"

# --- Setup ---
mock_setup

# Stub network functions that the daemon uses
network_flush_cache() { :; }
network_get_device() { eval "$1=br-lan"; }
network_get_subnet() { eval "$1=192.168.1.0/24"; }
network_get_subnet6() { eval "$1=fd00::/64"; }

LAN_DEV=""
LAN_SUBNET=""
LAN_SUBNET6=""
ULA=""

# Source the firewall functions
_lan_info() {
	network_flush_cache
	network_get_device LAN_DEV lan || LAN_DEV=br-lan
	network_get_subnet LAN_SUBNET lan || LAN_SUBNET="192.168.1.0/24"
	network_get_subnet6 LAN_SUBNET6 lan
	ULA=$(uci -q get network.globals.ula_prefix)
}

_nft_block() {
	_lan_info
	local v6_local="fe80::/10, ff00::/8"
	[ -n "$LAN_SUBNET6" ] && v6_local="$v6_local, $LAN_SUBNET6"
	[ -n "$ULA" ] && v6_local="$v6_local, $ULA"

	nft -f - <<-EOF
		table inet netlock {
			chain prerouting {
				type filter hook prerouting priority -300; policy accept;
				iifname "$LAN_DEV" ip  daddr $LAN_SUBNET accept
				iifname "$LAN_DEV" ip  daddr { 224.0.0.0/4, 255.255.255.255 } accept
				iifname "$LAN_DEV" meta nfproto ipv4 counter drop
				iifname "$LAN_DEV" ip6 daddr { $v6_local } accept
				iifname "$LAN_DEV" meta nfproto ipv6 counter drop
			}
		}
	EOF
}

_nft_unblock() {
	nft delete table inet netlock 2>/dev/null
	return 0
}

# --- Tests ---

describe "nft_block creates rules"

_nft_block
assert_true 'mock_nft_is_blocked' "nft rules file exists after block"

# Read the generated rules
rules=$(cat "${MOCK_DIR}/nft_state")
assert_contains "$rules" "table inet netlock" "contains table declaration"
assert_contains "$rules" "priority -300" "hooks at priority -300"
assert_contains "$rules" "br-lan" "uses correct LAN device"
assert_contains "$rules" "192.168.1.0/24" "allows LAN subnet"
assert_contains "$rules" "224.0.0.0/4" "allows multicast"
assert_contains "$rules" "255.255.255.255" "allows broadcast"
assert_contains "$rules" "fe80::/10" "allows IPv6 link-local"
assert_contains "$rules" "ff00::/8" "allows IPv6 multicast"
assert_contains "$rules" "fd00::/64" "allows IPv6 LAN subnet"
assert_contains "$rules" "counter drop" "drops non-matching traffic"

describe "nft_unblock removes rules"

_nft_unblock
assert_false 'mock_nft_is_blocked' "nft rules file removed after unblock"

describe "nft_block with ULA prefix"

mock_uci_set "network.globals.ula_prefix" "fd12:3456::/48"
_nft_block
rules=$(cat "${MOCK_DIR}/nft_state")
assert_contains "$rules" "fd12:3456::/48" "includes ULA prefix in allowed list"

describe "nft_block without IPv6"

network_get_subnet6() { eval "$1="; }
_nft_block
rules=$(cat "${MOCK_DIR}/nft_state")
assert_contains "$rules" "fe80::/10" "still allows link-local without IPv6 subnet"

# --- Teardown & Summary ---
mock_teardown
test_summary
