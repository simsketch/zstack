#!/usr/bin/env bash
# Tests for checklist.py: parsing How to test blocks, grouping, smoke list,
# candidate journey tests, recording results and gh failures.
# shellcheck source-path=SCRIPTDIR source=helpers.sh
. "$(dirname "$0")/helpers.sh"
CHECKLIST="$ZT_SCRIPTS/checklist.py"

new_sandbox
export ZSTACK_GH="$ZT_STUBS/gh"
OUTDIR="$ZSTACK_STATE_DIR/checklists"

python3 - "$SANDBOX/gh/pr-list.json" <<'PY'
import json, sys
well = """## What changed
Profile name editing.

## How to test
Environment: staging
Platform: web
Screen: Settings > Profile
Steps:
1. Open settings
2. Change the display name
Expected: The new name shows in the header

## Drive-bys
None.
"""
loose = """Some summary.

### how to test
- **Environment:** production
- **Endpoint:** POST /api/orders
- **Steps:**
  - send an order
  - read the response
- **Expected result:** 201 with an order id
"""
none = "Refactor only, nothing to click."
prs = [
    {"number": 1, "title": "Edit profile name", "body": well, "mergedAt": "2026-10-01T09:00:00Z", "url": "u1"},
    {"number": 2, "title": "Orders API", "body": loose, "mergedAt": "2026-10-01T10:00:00Z", "url": "u2"},
    {"number": 3, "title": "Tidy utils", "body": none, "mergedAt": "2026-10-01T11:00:00Z", "url": "u3"},
]
json.dump(prs, open(sys.argv[1], "w"))
PY
printf '%s\n' '# Smoke list' '- [ ] Sign in: open /login and sign in -> dashboard loads' > "$ZSTACK_STATE_DIR/smoke.md"

export ZSTACK_NOW="2026-10-01T12:00:00Z"
OUT="$(python3 "$CHECKLIST" generate --since 2026-09-30T00:00:00Z 2>&1)"; RC=$?
assert_eq 0 "$RC" "generate exits 0"
FILE="$OUTDIR/checklist-2026-10-01.md"
check "checklist file written" [ -f "$FILE" ]
assert_contains "$OUT" "$FILE" "generate prints the file path"
assert_contains "$(cat "$SANDBOX/gh/calls.log")" "pr list" "generate lists PRs through gh"
assert_contains "$(cat "$SANDBOX/gh/calls.log")" "--state merged" "generate asks for merged PRs"
assert_contains "$(cat "$SANDBOX/gh/calls.log")" "merged:>=2026-09-30" "generate searches from --since"
BODY="$(cat "$FILE")"
assert_eq 2 "$(grep -c '^- \[ \] PR #' "$FILE")" "two PR items"
assert_contains "$BODY" "- [ ] PR #1 Edit profile name — Settings > Profile: 1. Open settings; 2. Change the display name -> expected The new name shows in the header  result:" "well-formed block item"
assert_contains "$BODY" "PR #2 Orders API — POST /api/orders: send an order; read the response -> expected 201 with an order id  result:" "loose block item"
assert_contains "$BODY" "## No test steps" "no test steps section"
assert_contains "$(sed -n '/^## No test steps/,/^## /p' "$FILE")" "PR #3 Tidy utils" "PR without a block is listed under no test steps"
assert_contains "$BODY" "## Smoke" "smoke section"
assert_contains "$(sed -n '/^## Smoke/,$p' "$FILE")" "- [ ] Sign in: open /login and sign in -> dashboard loads  result:" "smoke item carries a result field"
assert_contains "$(sed -n '/^## staging/,/^## /p' "$FILE")" "PR #1" "PR #1 under staging"
assert_contains "$(sed -n '/^## production/,/^## /p' "$FILE")" "PR #2" "PR #2 under production"
assert_not_contains "$(sed -n '/^## production/,/^## /p' "$FILE")" "PR #1" "PR #1 not under production"
assert_not_contains "$BODY" "## Candidate journey tests" "no candidates on the first checklist"
check "history updated" [ -s "$OUTDIR/history.jsonl" ]

# --from-json, three days with the same item -> candidate journey test.
cp "$SANDBOX/gh/pr-list.json" "$SANDBOX/prs.json"
for d in 02 03; do
  ZSTACK_NOW="2026-10-${d}T12:00:00Z" python3 "$CHECKLIST" generate --from-json "$SANDBOX/prs.json" --since 2000-01-01 >/dev/null 2>&1
done
DAY3="$OUTDIR/checklist-2026-10-03.md"
check "day 3 checklist written" [ -f "$DAY3" ]
assert_contains "$(sed -n '/^## Candidate journey tests/,$p' "$DAY3")" "Settings > Profile" "item seen on 3 checklists is a candidate"
assert_not_contains "$(cat "$OUTDIR/checklist-2026-10-02.md")" "## Candidate journey tests" "two checklists are not enough"
ZSTACK_NOW="2026-10-03T18:00:00Z" python3 "$CHECKLIST" generate --from-json "$SANDBOX/prs.json" --since 2000-01-01 >/dev/null 2>&1
assert_eq 3 "$(wc -l < "$OUTDIR/history.jsonl" | tr -d ' ')" "regenerating the same day replaces its history entry"

# --out writes elsewhere.
python3 "$CHECKLIST" generate --from-json "$SANDBOX/prs.json" --since 2000-01-01 --out "$SANDBOX/out" >/dev/null 2>&1
check "--out directory used" [ -f "$SANDBOX/out/checklist-2026-10-01.md" ]

# record.
REC="$SANDBOX/filled.md"
sed -e 's/^- \[ \] \(PR #1 .*\)result:$/- [x] \1result: pass name updated/' \
    -e 's/^- \[ \] \(PR #2 .*\)result:$/- [x] \1result: fail returns 500/' "$FILE" > "$REC"
: > "$SANDBOX/gh/calls.log"
OUT="$(python3 "$CHECKLIST" record "$REC" --dry-run 2>&1)"; RC=$?
assert_eq 0 "$RC" "record --dry-run exits 0"
assert_contains "$OUT" "gh pr comment 1 --body" "dry run prints the pass comment"
assert_contains "$OUT" "gh pr comment 2 --body" "dry run prints the fail comment"
assert_contains "$OUT" "open bug: PR #2" "a failure prints open bug"
assert_eq "" "$(cat "$SANDBOX/gh/calls.log")" "dry run calls no gh"
OUT="$(python3 "$CHECKLIST" record "$REC" 2>&1)"; RC=$?
assert_eq 0 "$RC" "record exits 0"
assert_contains "$(cat "$SANDBOX/gh/calls.log")" "pr comment 1 --body" "record comments on PR 1"
assert_contains "$(cat "$SANDBOX/gh/calls.log")" "pr comment 2 --body" "record comments on PR 2"
echo 1 > "$SANDBOX/gh/exit"
OUT="$(python3 "$CHECKLIST" record "$REC" 2>&1)"; RC=$?
assert_eq 1 "$RC" "record exits 1 when gh fails"
assert_not_contains "$OUT" "Traceback" "record gh failure prints no traceback"

# gh failing makes generate exit 1 with one line and no partial file.
rm -f "$FILE"
OUT="$(python3 "$CHECKLIST" generate --since 2026-09-30T00:00:00Z 2>&1)"; RC=$?
assert_eq 1 "$RC" "generate exits 1 when gh fails"
assert_eq 1 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "gh failure prints one line"
assert_not_contains "$OUT" "Traceback" "gh failure prints no traceback"
check_not "no checklist written on gh failure" [ -f "$FILE" ]
rm "$SANDBOX/gh/exit"

# gh missing entirely.
OUT="$(ZSTACK_GH="$SANDBOX/no-such-gh" python3 "$CHECKLIST" generate --since 2026-09-30T00:00:00Z 2>&1)"; RC=$?
assert_eq 1 "$RC" "missing gh exits 1"
assert_eq 1 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "missing gh prints one line"

finish
