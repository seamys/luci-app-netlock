#!/bin/sh
# Test: Presence detection logic
# Tests the 3-tier detection: AP association → neighbor table → ping

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/framework.sh"
. "${SCRIPT_DIR}/mocks.sh"

# --- Setup ---
mock_setup

# Source just the detection functions from the daemon
# We simulate the environment the daemon expects
MAC_RE='([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}'

_list_ap_ifaces() {
	if [ -n "$monitor_ifaces" ]; then
		echo "$monitor_ifaces"
	else
		ubus list 2>/dev/null | sed -n 's/^hostapd\.//p'
	fi
}

_get_associated_macs() {
	local ifc
	for ifc in $(_list_ap_ifaces); do
		iwinfo "$ifc" assoclist 2>/dev/null | grep -oE "$MAC_RE"
	done | tr 'A-F' 'a-f' | sort -u
}

_neigh_reachable() {
	ip neigh show 2>/dev/null | awk -v m="$1" '
		tolower($0) ~ m && /REACHABLE|DELAY|PROBE/ { found=1 }
		END { exit !found }'
}

_lease_ip() {
	awk -v m="$1" 'tolower($2)==m {print $3; exit}' /tmp/dhcp.leases 2>/dev/null
}

_target_ip() {
	local ip
	ip=$(ip neigh show 2>/dev/null | awk -v m="$1" 'tolower($0) ~ m {print $1; exit}')
	[ -n "$ip" ] || ip=$(_lease_ip "$1")
	echo "$ip"
}

_phone_present() {
	MATCHED=""
	local assoc t ip present=0
	assoc=$(_get_associated_macs)

	for t in $target_macs; do
		if echo "$assoc" | grep -qx "$t"; then
			MATCHED="$MATCHED $t"; present=1; continue
		fi
		if _neigh_reachable "$t"; then
			MATCHED="$MATCHED $t"; present=1; continue
		fi
		ip=$(_target_ip "$t")
		if [ -n "$ip" ] && ping -c1 -W1 "$ip" >/dev/null 2>&1; then
			MATCHED="$MATCHED $t"; present=1; continue
		fi
	done

	[ "$present" = 1 ]
}

# --- Tests ---

describe "AP Association Detection"

mock_set_ubus_list "hostapd.phy0-ap0"
target_macs="aa:bb:cc:dd:ee:ff"
monitor_ifaces=""

mock_set_assoclist "AA:BB:CC:DD:EE:FF  -65 dBm"
assert_true '_phone_present' "detects MAC on AP (case insensitive)"
assert_contains "$MATCHED" "aa:bb:cc:dd:ee:ff" "correct MAC in MATCHED"

mock_set_assoclist "11:22:33:44:55:66  -70 dBm"
assert_false '_phone_present' "does not detect unrelated MAC"

describe "Neighbor Table Detection"

mock_set_assoclist ""  # clear AP associations
mock_set_neighbors "192.168.1.100 dev br-lan lladdr aa:bb:cc:dd:ee:ff REACHABLE"
assert_true '_phone_present' "detects MAC in neighbor table (REACHABLE)"

mock_set_neighbors "192.168.1.100 dev br-lan lladdr aa:bb:cc:dd:ee:ff DELAY"
assert_true '_phone_present' "detects MAC in neighbor table (DELAY)"

mock_set_neighbors "192.168.1.100 dev br-lan lladdr aa:bb:cc:dd:ee:ff PROBE"
assert_true '_phone_present' "detects MAC in neighbor table (PROBE)"

mock_set_neighbors "192.168.1.100 dev br-lan lladdr aa:bb:cc:dd:ee:ff STALE"
mock_ping_fail
assert_false '_phone_present' "ignores STALE neighbor (falls through to ping)"

describe "Ping Fallback Detection"

mock_set_assoclist ""
mock_set_neighbors "192.168.1.100 dev br-lan lladdr aa:bb:cc:dd:ee:ff STALE"
mock_ping_success
assert_true '_phone_present' "detects via ping when neighbor is STALE"

mock_set_neighbors ""
mock_ping_fail
assert_false '_phone_present' "fails when no neighbor and ping fails"

describe "Multiple Target MACs"

target_macs="aa:bb:cc:dd:ee:ff 11:22:33:44:55:66"
mock_set_assoclist "11:22:33:44:55:66  -50 dBm"
mock_set_neighbors ""
mock_ping_fail
assert_true '_phone_present' "detects any one of multiple targets"
assert_contains "$MATCHED" "11:22:33:44:55:66" "correct MAC matched"

describe "Monitor Interface Override"

monitor_ifaces="phy1-ap0"
mock_set_ubus_list "hostapd.phy0-ap0\nhostapd.phy1-ap0"
mock_set_assoclist "AA:BB:CC:DD:EE:FF  -60 dBm"
target_macs="aa:bb:cc:dd:ee:ff"
assert_true '_phone_present' "detects on specified monitor interface"

# --- Teardown & Summary ---
mock_teardown
test_summary
