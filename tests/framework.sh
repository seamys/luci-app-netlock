#!/bin/sh
# Test framework for netlock
# Provides assertion helpers and test runner.
# Compatible with POSIX sh / busybox ash.

# --- Test state ---
_TESTS_RUN=0
_TESTS_PASS=0
_TESTS_FAIL=0
_CURRENT_TEST=""
_FAILURES=""

# --- Colors (if terminal supports) ---
if [ -t 1 ]; then
	_GREEN='\033[0;32m'
	_RED='\033[0;31m'
	_YELLOW='\033[0;33m'
	_BOLD='\033[1m'
	_RESET='\033[0m'
else
	_GREEN='' _RED='' _YELLOW='' _BOLD='' _RESET=''
fi

# --- Assertions ---

# assert_equal <expected> <actual> [description]
assert_equal() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if [ "$1" = "$2" ]; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${3:-values equal}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${3:-values equal}"
		printf "      expected: '%s'\n" "$1"
		printf "      actual:   '%s'\n" "$2"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${3:-values equal}"
	fi
}

# assert_not_equal <unexpected> <actual> [description]
assert_not_equal() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if [ "$1" != "$2" ]; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${3:-values not equal}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${3:-values not equal}"
		printf "      unexpected: '%s'\n" "$1"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${3:-values not equal}"
	fi
}

# assert_true <command> [description]
assert_true() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if eval "$1" >/dev/null 2>&1; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${2:-command succeeds}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${2:-command succeeds}"
		printf "      command: %s\n" "$1"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${2:-command succeeds}"
	fi
}

# assert_false <command> [description]
assert_false() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if ! eval "$1" >/dev/null 2>&1; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${2:-command fails}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${2:-command fails}"
		printf "      command should fail: %s\n" "$1"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${2:-command fails}"
	fi
}

# assert_contains <haystack> <needle> [description]
assert_contains() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if echo "$1" | grep -qF "$2"; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${3:-contains expected text}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${3:-contains expected text}"
		printf "      needle:   '%s'\n" "$2"
		printf "      haystack: '%s'\n" "$(echo "$1" | head -3)"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${3:-contains expected text}"
	fi
}

# assert_match <text> <regex> [description]
assert_match() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if echo "$1" | grep -qE "$2"; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${3:-matches regex}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${3:-matches regex}"
		printf "      text:  '%s'\n" "$1"
		printf "      regex: '%s'\n" "$2"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${3:-matches regex}"
	fi
}

# assert_no_match <text> <regex> [description]
assert_no_match() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if ! echo "$1" | grep -qE "$2"; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${3:-does not match regex}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${3:-does not match regex}"
		printf "      text:  '%s'\n" "$1"
		printf "      regex: '%s'\n" "$2"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${3:-does not match regex}"
	fi
}

# assert_file_exists <path> [description]
assert_file_exists() {
	_TESTS_RUN=$((_TESTS_RUN + 1))
	if [ -f "$1" ]; then
		_TESTS_PASS=$((_TESTS_PASS + 1))
		printf "    ${_GREEN}✓${_RESET} %s\n" "${2:-file exists: $1}"
	else
		_TESTS_FAIL=$((_TESTS_FAIL + 1))
		printf "    ${_RED}✗${_RESET} %s\n" "${2:-file exists: $1}"
		_FAILURES="${_FAILURES}\n  - [${_CURRENT_TEST}] ${2:-file exists: $1}"
	fi
}

# --- Test grouping ---

describe() {
	_CURRENT_TEST="$1"
	printf "\n  ${_BOLD}%s${_RESET}\n" "$1"
}

# --- Summary ---

test_summary() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if [ "$_TESTS_FAIL" -eq 0 ]; then
		printf "  ${_GREEN}✓ All %d tests passed${_RESET}\n" "$_TESTS_RUN"
	else
		printf "  ${_RED}✗ %d of %d tests failed${_RESET}\n" "$_TESTS_FAIL" "$_TESTS_RUN"
		printf "  Failures:${_FAILURES}\n"
	fi
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	[ "$_TESTS_FAIL" -eq 0 ]
}
