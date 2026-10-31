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

# The Codex hook command finds the script through PLUGIN_ROOT (or CLAUDE_PLUGIN_ROOT) and exits 0 quietly
# when neither is set, so a harness that exposes neither variable never shows a hook error.
CMD="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]["hooks"][0]["command"])' "$ZT_ROOT/hooks/codex-hooks.json")"
OUT="$(env -u CLAUDE_PLUGIN_ROOT PLUGIN_ROOT="$ZT_ROOT" sh -c "$CMD" </dev/null 2>&1)"; RC=$?
assert_eq 0 "$RC" "codex hook command exits 0 with PLUGIN_ROOT"
assert_contains "$OUT" "zstack" "codex hook command prints the hint with PLUGIN_ROOT"
OUT="$(env -u PLUGIN_ROOT CLAUDE_PLUGIN_ROOT="$ZT_ROOT" sh -c "$CMD" </dev/null 2>&1)"; RC=$?
assert_contains "$OUT" "zstack" "codex hook command falls back to CLAUDE_PLUGIN_ROOT"
OUT="$(env -u PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT sh -c "$CMD" </dev/null 2>&1)"; RC=$?
assert_eq 0 "$RC" "codex hook command exits 0 with no plugin root"
assert_eq "" "$OUT" "codex hook command prints nothing with no plugin root"

finish
