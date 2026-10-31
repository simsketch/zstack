#!/usr/bin/env bash
# Shared helpers for the zstack skill script tests. Source from a test file
# and call `finish` at the end. Self-contained: the skill folder ships alone.
# shellcheck disable=SC2034
ZT_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ZT_SCRIPTS="$ZT_SKILL/scripts"
ZT_STUBS="$ZT_SKILL/tests/stubs"
ZT_PASS=0
ZT_FAIL=0

# Keep the developer's own config and identity out of every test.
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="zstack test" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="zstack test" GIT_COMMITTER_EMAIL="test@example.com"
unset ZSTACK_STATE_DIR ZSTACK_GH ZSTACK_FLEET ZSTACK_NOW

zt_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/zstack-test.XXXXXX"
}

# new_sandbox: sets SANDBOX (exported, read by stubs/gh), a fake HOME and a
# fresh state dir. Callers point ZSTACK_GH at "$ZT_STUBS/gh" when needed.
new_sandbox() {
  SANDBOX="$(zt_tmpdir)"
  export SANDBOX
  mkdir -p "$SANDBOX/gh" "$SANDBOX/home" "$SANDBOX/state"
  export HOME="$SANDBOX/home"
  export ZSTACK_STATE_DIR="$SANDBOX/state"
}

# new_repo <dir>: a git repo with one commit.
new_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config commit.gpgsign false
  echo seed > "$1/README.md"
  git -C "$1" add README.md
  git -C "$1" commit -q -m seed
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
