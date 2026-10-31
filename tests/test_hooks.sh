#!/usr/bin/env bash
# Tests for hooks/session-start.sh.
# shellcheck source=tests/helpers.sh
. "$(dirname "$0")/helpers.sh"
HOOK="$ZT_ROOT/hooks/session-start.sh"

for h in claude codex gemini ""; do
  OUT="$(bash "$HOOK" $h </dev/null 2>&1)"; RC=$?
  assert_eq 0 "$RC" "hook exits 0 (${h:-no arg})"
  assert_eq 2 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "hook prints two lines (${h:-no arg})"
  assert_contains "$OUT" "zstack" "hook names the skill (${h:-no arg})"
done
check "hook is executable" [ -x "$HOOK" ]

finish
