#!/usr/bin/env bash
# Shared test helpers. Source from a test file; call `finish` at the end.
# shellcheck disable=SC2034
ZT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ZT_PASS=0
ZT_FAIL=0

zt_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/zstack-test.XXXXXX"
}

pass() { ZT_PASS=$((ZT_PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { ZT_FAIL=$((ZT_FAIL + 1)); printf '  FAIL %s\n' "$1"; }

# assert_eq <expected> <actual> <label>
assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected '$1', got '$2')"; fi
}

# assert_contains <haystack> <needle> <label>
assert_contains() {
  case "$1" in
    *"$2"*) pass "$3" ;;
    *) fail "$3 (missing '$2' in: $1)" ;;
  esac
}

# assert_not_contains <haystack> <needle> <label>
assert_not_contains() {
  case "$1" in
    *"$2"*) fail "$3 (unexpected '$2' in: $1)" ;;
    *) pass "$3" ;;
  esac
}

# check <label> <command...>: pass when the command succeeds
check() {
  local label="$1"; shift
  if "$@"; then pass "$label"; else fail "$label"; fi
}

# check_not <label> <command...>: pass when the command fails
check_not() {
  local label="$1"; shift
  if "$@"; then fail "$label"; else pass "$label"; fi
}

finish() {
  printf '  %d passed, %d failed\n' "$ZT_PASS" "$ZT_FAIL"
  [ "$ZT_FAIL" -eq 0 ]
}
