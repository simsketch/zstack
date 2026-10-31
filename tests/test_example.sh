#!/usr/bin/env bash
# Tests for skills/zstack/example: the demo repo builder and the trigger runner's usage.
# shellcheck source=tests/helpers.sh
. "$(dirname "$0")/helpers.sh"
EX="$ZT_ROOT/skills/zstack/example"

d="$(zt_tmpdir)/acme"
OUT="$(bash "$EX/setup-demo.sh" "$d" 2>&1)"; RC=$?
assert_eq 0 "$RC" "setup-demo builds the repo"
assert_contains "$OUT" "feature/tags" "setup-demo reports its branches"

(cd "$d" && python3 -m unittest discover -s tests >/dev/null 2>&1); RC=$?
assert_eq 0 "$RC" "demo tests pass despite the planted bugs"

n="$d/notes.json"
(cd "$d" && for t in a b c; do ACME_NOTES_FILE="$n" python3 -m acme_notes add "$t" >/dev/null; done)
rows="$(cd "$d" && ACME_NOTES_FILE="$n" python3 -m acme_notes export "$d/out.csv" >/dev/null && wc -l < "$d/out.csv" | tr -d ' ')"
assert_eq 3 "$rows" "export drops the last row (header + 2 of 3)"
listed="$(cd "$d" && ACME_NOTES_FILE="$n" python3 -m acme_notes list --limit 3 | wc -l | tr -d ' ')"
assert_eq 2 "$listed" "list --limit 3 shows 2 (sibling off-by-one)"

has_branch() { git -C "$d" rev-parse -q --verify "$1" >/dev/null; }
check "branch feature/tags exists" has_branch feature/tags
check "branch wip/search exists" has_branch wip/search
check "handoff file exists" test -f "$d/.git/zstack/handoffs/wip/search.md"
assert_eq main "$(git -C "$d" branch --show-current)" "demo is left on main"
assert_eq "" "$(git -C "$d" status --porcelain)" "demo tree is clean"

OUT="$(bash "$EX/setup-demo.sh" "$d" 2>&1)"; RC=$?
assert_eq 2 "$RC" "setup-demo refuses a non-empty dir"

OUT="$(bash "$EX/run-trigger-tests.sh" 2>&1)"; RC=$?
assert_eq 2 "$RC" "trigger runner without a harness prints usage"
assert_eq 10 "$(grep -c . "$EX/trigger-prompts.txt")" "ten trigger prompts"

finish
