#!/bin/sh
# Test: rpcd backend methods (status, clients, interfaces)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/framework.sh"
. "${SCRIPT_DIR}/mocks.sh"

RPCD_SRC="${SCRIPT_DIR}/../src/rpcd/netlock"

# --- Setup ---
mock_setup

# Create mock jshn.sh at the path the rpcd expects
mkdir -p "${MOCK_DIR}/usr/share/libubox"
cat > "${MOCK_DIR}/usr/share/libubox/jshn.sh" <<'EOF'
#!/bin/sh
# Minimal jshn mock for testing
_JSON_BUF=""
_JSON_DEPTH=0
_JSON_FIRST="1"

json_init() { _JSON_BUF=""; _JSON_DEPTH=0; _JSON_FIRST="1"; }
json_add_array() {
	[ "$_JSON_FIRST" = "0" ] && _JSON_BUF="${_JSON_BUF},"
	_JSON_BUF="${_JSON_BUF}\"$1\":["
	_JSON_FIRST="1"
	_JSON_DEPTH=$((_JSON_DEPTH + 1))
}
json_add_object() {
	[ "$_JSON_FIRST" = "0" ] && _JSON_BUF="${_JSON_BUF},"
	_JSON_BUF="${_JSON_BUF}{"
	_JSON_FIRST="1"
	_JSON_DEPTH=$((_JSON_DEPTH + 1))
}
json_add_string() {
	[ "$_JSON_FIRST" = "0" ] && _JSON_BUF="${_JSON_BUF},"
	if [ -n "$1" ]; then
		_JSON_BUF="${_JSON_BUF}\"$1\":\"$2\""
	else
		_JSON_BUF="${_JSON_BUF}\"$2\""
	fi
	_JSON_FIRST="0"
}
json_close_object() { _JSON_BUF="${_JSON_BUF}}"; _JSON_FIRST="0"; _JSON_DEPTH=$((_JSON_DEPTH - 1)); }
json_close_array() { _JSON_BUF="${_JSON_BUF}]"; _JSON_FIRST="0"; _JSON_DEPTH=$((_JSON_DEPTH - 1)); }
json_dump() { echo "{${_JSON_BUF}}"; }
EOF

# Create a patched copy of the rpcd that sources our mock jshn
RPCD="${MOCK_DIR}/rpcd_netlock"
sed -e "s|. /usr/share/libubox/jshn.sh|. ${MOCK_DIR}/usr/share/libubox/jshn.sh|" \
    -e "s|STATUS_FILE=/var/run/netlock.json|STATUS_FILE=${MOCK_DIR}/var/run/netlock.json|" \
    "$RPCD_SRC" > "$RPCD"
chmod +x "$RPCD"

# --- Tests ---

describe "rpcd list method"

result=$(CONF=netlock sh "$RPCD" list)
assert_contains "$result" "status" "list includes status method"
assert_contains "$result" "clients" "list includes clients method"
assert_contains "$result" "interfaces" "list includes interfaces method"

describe "rpcd status method — no status file"

rm -f "${MOCK_DIR}/var/run/netlock.json"
result=$(CONF=netlock sh "$RPCD" call status)
assert_contains "$result" '"enabled":0' "default status shows enabled=0"
assert_contains "$result" '"targets":[]' "default status has empty targets"

describe "rpcd status method — with status file"

cat > "${MOCK_DIR}/var/run/netlock.json" <<'STATUSJSON'
{"enabled":1,"present":1,"blocked":0,"last_seen":1700000000,"targets":["aa:bb:cc:dd:ee:ff"],"matched":["aa:bb:cc:dd:ee:ff"]}
STATUSJSON
result=$(CONF=netlock sh "$RPCD" call status)
assert_contains "$result" '"enabled":1' "reads enabled from status file"
assert_contains "$result" '"present":1' "reads present from status file"
assert_contains "$result" "aa:bb:cc:dd:ee:ff" "reads target MAC from status file"

describe "rpcd interfaces method"

# Mock ubus to list hostapd interfaces
mock_set_ubus_list "hostapd.phy0-ap0
hostapd.phy1-ap0
system
network"

result=$(CONF=netlock sh "$RPCD" call interfaces)
assert_contains "$result" "phy0-ap0" "interfaces lists phy0-ap0"
assert_contains "$result" "phy1-ap0" "interfaces lists phy1-ap0"

describe "rpcd interfaces method — no hostapd interfaces"

mock_set_ubus_list "system
network"

result=$(CONF=netlock sh "$RPCD" call interfaces)
assert_contains "$result" "interfaces" "returns interfaces key even when empty"

# --- Teardown & Summary ---
mock_teardown
test_summary
