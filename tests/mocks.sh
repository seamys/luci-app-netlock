#!/bin/sh
# Mock layer for UCI, nftables, iwinfo, and system commands.
# Allows tests to run on any dev machine without OpenWrt.

MOCK_DIR="${TEST_TMPDIR:-/tmp/netlock-test}"
MOCK_UCI_DIR="${MOCK_DIR}/uci"
MOCK_FILES_DIR="${MOCK_DIR}/files"

# --- Setup/Teardown ---

mock_setup() {
	rm -rf "$MOCK_DIR"
	mkdir -p "$MOCK_UCI_DIR" "$MOCK_FILES_DIR"
	mkdir -p "${MOCK_DIR}/bin"
	mkdir -p "${MOCK_DIR}/var/run"

	_create_mock_uci
	_create_mock_nft
	_create_mock_iwinfo
	_create_mock_ip
	_create_mock_ping
	_create_mock_logger
	_create_mock_ubus

	# Prepend mock bin to PATH
	export PATH="${MOCK_DIR}/bin:$PATH"
	export MOCK_DIR MOCK_UCI_DIR MOCK_FILES_DIR
	export STATUS_FILE="${MOCK_DIR}/var/run/netlock.json"
	export STATUS_TMP="${MOCK_DIR}/var/run/netlock.json.tmp"
}

mock_teardown() {
	rm -rf "$MOCK_DIR"
}

# --- UCI Mock ---

_create_mock_uci() {
	cat > "${MOCK_DIR}/bin/uci" <<'MOCK_EOF'
#!/bin/sh
UCI_DIR="${MOCK_UCI_DIR}"

_get_file() {
	echo "${UCI_DIR}/$(echo "$1" | cut -d. -f1)"
}

# Handle -q flag
quiet=0
if [ "$1" = "-q" ]; then
	quiet=1
	shift
fi

case "$1" in
	get)
		shift
		file=$(_get_file "$1")
		key="$1"
		if [ -f "$file" ]; then
			val=$(grep "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2-)
			if [ -n "$val" ]; then
				echo "$val"
			else
				[ "$quiet" = 1 ] || echo "uci: Entry not found" >&2
				return 1
			fi
		else
			[ "$quiet" = 1 ] || echo "uci: Entry not found" >&2
			return 1
		fi
		;;
	set)
		shift
		file=$(_get_file "$1")
		key=$(echo "$1" | cut -d= -f1)
		val=$(echo "$1" | cut -d= -f2- | tr -d "'")
		mkdir -p "$(dirname "$file")"
		if grep -q "^${key}=" "$file" 2>/dev/null; then
			sed -i "s|^${key}=.*|${key}=${val}|" "$file"
		else
			echo "${key}=${val}" >> "$file"
		fi
		;;
	commit)
		# no-op in mock
		;;
	*)
		;;
esac
MOCK_EOF
	chmod +x "${MOCK_DIR}/bin/uci"
}

# --- nftables Mock ---

_create_mock_nft() {
	cat > "${MOCK_DIR}/bin/nft" <<'MOCK_EOF'
#!/bin/sh
NFT_STATE="${MOCK_DIR}/nft_state"

case "$1" in
	-f)
		# Read from stdin, record that rules were applied
		cat > "$NFT_STATE"
		;;
	delete)
		rm -f "$NFT_STATE"
		;;
esac
MOCK_EOF
	chmod +x "${MOCK_DIR}/bin/nft"
}

# --- iwinfo Mock ---

_create_mock_iwinfo() {
	cat > "${MOCK_DIR}/bin/iwinfo" <<'MOCK_EOF'
#!/bin/sh
ASSOC_FILE="${MOCK_DIR}/iwinfo_assoclist"
if [ "$2" = "assoclist" ] && [ -f "$ASSOC_FILE" ]; then
	cat "$ASSOC_FILE"
fi
MOCK_EOF
	chmod +x "${MOCK_DIR}/bin/iwinfo"
}

# --- ip Mock ---

_create_mock_ip() {
	cat > "${MOCK_DIR}/bin/ip" <<'MOCK_EOF'
#!/bin/sh
NEIGH_FILE="${MOCK_DIR}/ip_neigh"
case "$1" in
	neigh)
		if [ -f "$NEIGH_FILE" ]; then
			cat "$NEIGH_FILE"
		fi
		;;
esac
MOCK_EOF
	chmod +x "${MOCK_DIR}/bin/ip"
}

# --- ping Mock ---

_create_mock_ping() {
	cat > "${MOCK_DIR}/bin/ping" <<'MOCK_EOF'
#!/bin/sh
PING_SUCCESS="${MOCK_DIR}/ping_success"
if [ -f "$PING_SUCCESS" ]; then
	exit 0
else
	exit 1
fi
MOCK_EOF
	chmod +x "${MOCK_DIR}/bin/ping"
}

# --- logger Mock ---

_create_mock_logger() {
	cat > "${MOCK_DIR}/bin/logger" <<'MOCK_EOF'
#!/bin/sh
LOG_FILE="${MOCK_DIR}/logger.log"
shift  # skip -t
tag="$1"; shift
echo "[$tag] $*" >> "$LOG_FILE"
MOCK_EOF
	chmod +x "${MOCK_DIR}/bin/logger"
}

# --- ubus Mock ---

_create_mock_ubus() {
	cat > "${MOCK_DIR}/bin/ubus" <<'MOCK_EOF'
#!/bin/sh
UBUS_LIST="${MOCK_DIR}/ubus_list"
UBUS_CLIENTS="${MOCK_DIR}/ubus_clients"

case "$1" in
	list)
		if [ -f "$UBUS_LIST" ]; then
			cat "$UBUS_LIST"
		fi
		;;
	-S)
		shift
		if [ "$1" = "call" ] && [ -f "$UBUS_CLIENTS" ]; then
			cat "$UBUS_CLIENTS"
		fi
		;;
esac
MOCK_EOF
	chmod +x "${MOCK_DIR}/bin/ubus"
}

# --- Helper: Set mock UCI values ---

mock_uci_set() {
	local file="${MOCK_UCI_DIR}/$(echo "$1" | cut -d. -f1)"
	local key="$1"
	local val="$2"
	mkdir -p "$(dirname "$file")"
	echo "${key}=${val}" >> "$file"
}

# --- Helper: Set mock iwinfo associations ---

mock_set_assoclist() {
	echo "$1" > "${MOCK_DIR}/iwinfo_assoclist"
}

# --- Helper: Set mock neighbor table ---

mock_set_neighbors() {
	echo "$1" > "${MOCK_DIR}/ip_neigh"
}

# --- Helper: Set ping to succeed/fail ---

mock_ping_success() {
	touch "${MOCK_DIR}/ping_success"
}

mock_ping_fail() {
	rm -f "${MOCK_DIR}/ping_success"
}

# --- Helper: Set ubus list output ---

mock_set_ubus_list() {
	echo "$1" > "${MOCK_DIR}/ubus_list"
}

# --- Helper: Check if nft rules are active ---

mock_nft_is_blocked() {
	[ -f "${MOCK_DIR}/nft_state" ]
}

# --- Helper: Read log output ---

mock_get_log() {
	cat "${MOCK_DIR}/logger.log" 2>/dev/null
}
