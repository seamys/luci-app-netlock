#!/bin/sh
# Test: Configuration loading and validation

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/framework.sh"
. "${SCRIPT_DIR}/mocks.sh"

# --- Setup ---
mock_setup

CONF=netlock

# Simulate _load_config from the daemon
_load_config() {
	enabled=$(uci -q get "$CONF.global.enabled" || echo 0)
	grace_period=$(uci -q get "$CONF.global.grace_period" || echo 300)
	poll_interval=$(uci -q get "$CONF.global.poll_interval" || echo 10)
	target_macs=$(uci -q get "$CONF.global.target_mac" | tr 'A-F' 'a-f')
	monitor_ifaces=$(uci -q get "$CONF.global.monitor_iface")

	[ "$poll_interval" -ge 2 ] 2>/dev/null || poll_interval=10
	[ "$grace_period" -ge 0 ] 2>/dev/null || grace_period=300
}

# --- Tests ---

describe "Default configuration values"

_load_config
assert_equal "0" "$enabled" "enabled defaults to 0 when not set"
assert_equal "300" "$grace_period" "grace_period defaults to 300"
assert_equal "10" "$poll_interval" "poll_interval defaults to 10"
assert_equal "" "$target_macs" "target_macs empty by default"
assert_equal "" "$monitor_ifaces" "monitor_ifaces empty by default"

describe "Configuration loading from UCI"

mock_uci_set "netlock.global.enabled" "1"
mock_uci_set "netlock.global.grace_period" "600"
mock_uci_set "netlock.global.poll_interval" "5"
mock_uci_set "netlock.global.target_mac" "AA:BB:CC:DD:EE:FF"

_load_config
assert_equal "1" "$enabled" "reads enabled=1"
assert_equal "600" "$grace_period" "reads grace_period=600"
assert_equal "5" "$poll_interval" "reads poll_interval=5"
assert_equal "aa:bb:cc:dd:ee:ff" "$target_macs" "normalizes MAC to lowercase"

describe "Poll interval minimum enforcement"

rm -f "${MOCK_UCI_DIR}/netlock"
mock_uci_set "netlock.global.enabled" "1"
mock_uci_set "netlock.global.grace_period" "300"
mock_uci_set "netlock.global.poll_interval" "1"
mock_uci_set "netlock.global.target_mac" "AA:BB:CC:DD:EE:FF"
_load_config
assert_equal "10" "$poll_interval" "poll_interval < 2 resets to 10"

rm -f "${MOCK_UCI_DIR}/netlock"
mock_uci_set "netlock.global.poll_interval" "0"
_load_config
assert_equal "10" "$poll_interval" "poll_interval=0 resets to 10"

rm -f "${MOCK_UCI_DIR}/netlock"
mock_uci_set "netlock.global.poll_interval" "abc"
_load_config
assert_equal "10" "$poll_interval" "non-numeric poll_interval resets to 10"

describe "Grace period validation"

rm -f "${MOCK_UCI_DIR}/netlock"
mock_uci_set "netlock.global.grace_period" "abc"
_load_config
assert_equal "300" "$grace_period" "non-numeric grace_period resets to 300"

rm -f "${MOCK_UCI_DIR}/netlock"
mock_uci_set "netlock.global.grace_period" "0"
_load_config
assert_equal "0" "$grace_period" "grace_period=0 is valid (immediate block)"

describe "MAC address validation patterns"

# Test the regex used for MAC matching
MAC_RE='([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}'

assert_match "AA:BB:CC:DD:EE:FF" "$MAC_RE" "uppercase MAC matches"
assert_match "aa:bb:cc:dd:ee:ff" "$MAC_RE" "lowercase MAC matches"
assert_match "aA:bB:cC:dD:eE:fF" "$MAC_RE" "mixed case MAC matches"
assert_no_match "GG:HH:II:JJ:KK:LL" "$MAC_RE" "invalid hex rejects"
assert_no_match "aa:bb:cc:dd:ee" "$MAC_RE" "incomplete MAC rejects"
assert_no_match "aa-bb-cc-dd-ee-ff" "$MAC_RE" "dash-separated MAC rejects"

# --- Teardown & Summary ---
mock_teardown
test_summary
