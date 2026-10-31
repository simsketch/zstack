#!/usr/bin/env bash
# Tests for ledger.py and trust.sh: track record, suggested and effective levels.
# shellcheck source-path=SCRIPTDIR source=helpers.sh
. "$(dirname "$0")/helpers.sh"
LEDGER="$ZT_SCRIPTS/ledger.py"
TRUST="$ZT_SCRIPTS/trust.sh"

new_sandbox
CONF="$ZSTACK_STATE_DIR/config"
row() { bash "$TRUST" --class "$1" 2>&1 | awk -v c="$1" '$1 == c'; }
col() { row "$1" | awk -v n="$2" '{print $n}'; }   # 1 class 2 merges 3 revert% 4 bug% 5 configured 6 effective 7 suggested

i=1
while [ "$i" -le 20 ]; do
  python3 "$LEDGER" add --pr "$i" --sha "d0c5$(printf '%036d' "$i")" --class docs --checks unit,lint >/dev/null || fail "add $i"
  i=$((i + 1))
done
assert_eq 20 "$(wc -l < "$ZSTACK_STATE_DIR/ledger.jsonl" | tr -d ' ')" "20 merge lines written"
assert_contains "$(head -1 "$ZSTACK_STATE_DIR/ledger.jsonl")" '"event": "merge"' "lines carry event=merge"
assert_contains "$(head -1 "$ZSTACK_STATE_DIR/ledger.jsonl")" '"ts": "' "lines carry ts"
python3 "$LEDGER" add --pr 1 --sha "d0c5$(printf '%036d' 1)" --class docs >/dev/null 2>&1
assert_eq 20 "$(wc -l < "$ZSTACK_STATE_DIR/ledger.jsonl" | tr -d ' ')" "a repeated merge is not added twice"

assert_eq 20 "$(col docs 2)" "docs shows 20 merges"
assert_eq L2 "$(col docs 7)" "20 clean docs merges suggest L2"
assert_eq L1 "$(col docs 5)" "docs configured defaults to L1"
assert_eq L0 "$(col solo 5)" "solo configured defaults to L0"
assert_contains "$(python3 "$LEDGER" stats --json)" '"suggested": "L2"' "stats --json carries suggested"
bash "$TRUST" --gate docs >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "--gate docs fails at the default L1"

printf 'trust.docs=L2\n' > "$CONF"
assert_eq L2 "$(col docs 6)" "configured L2 is effective L2"
bash "$TRUST" --gate docs >/dev/null 2>&1; RC=$?
assert_eq 0 "$RC" "--gate docs passes at L2"

python3 "$LEDGER" flag --sha "d0c5$(printf '%036d' 3)" --reverted >/dev/null; RC=$?
assert_eq 0 "$RC" "flag --reverted exits 0"
assert_eq L1 "$(col docs 6)" "a revert drops docs to effective L1"
assert_eq 5 "$(col docs 3)" "revert% is 5"
bash "$TRUST" --gate docs >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "--gate docs fails after the revert"

printf 'trust.docs=L2\ntrust.docs.since=2999-01-01\n' > "$CONF"
assert_eq L2 "$(col docs 6)" "a since date after the revert restores the level"
printf 'trust.docs=L2\ntrust.docs.since=2000-01-01\n' > "$CONF"
assert_eq L1 "$(col docs 6)" "a since date before the revert keeps the drop"

python3 "$LEDGER" flag --sha "d0c5$(printf '%036d' 4)" --bug BUG-12 >/dev/null
assert_eq 5 "$(col docs 4)" "bug% is 5"
python3 "$LEDGER" flag --sha "d0c5$(printf '%036d' 5)" --reverted >/dev/null
assert_eq L1 "$(col docs 7)" "revert rate above 5% suggests L1"
OUT="$(python3 "$LEDGER" flag --sha ffff --reverted 2>&1)"; RC=$?
assert_eq 1 "$RC" "flagging an unknown sha fails"
assert_contains "$OUT" "no merge recorded" "unknown sha is explained"

# Solo never above L1; L3 needs fleet.
printf 'trust.solo=L3\ntrust.feature=L3\n' > "$CONF"
assert_eq L1 "$(col solo 6)" "solo configured L3 is effective L1"
assert_eq L2 "$(col feature 6)" "L3 without fleet is capped at L2"
assert_eq L3 "$(ZSTACK_FLEET=1 col feature 6)" "L3 with ZSTACK_FLEET=1 is effective L3"
bash "$TRUST" --gate feature --level L3 >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "--gate --level L3 fails without fleet (capped at L2)"
bash "$TRUST" --gate feature >/dev/null 2>&1; RC=$?
assert_eq 0 "$RC" "--gate feature passes at effective L2"
mkdir -p "$HOME/.agents/skills/zstack-fleet"
assert_eq L3 "$(col feature 6)" "fleet skill folder enables L3"
bash "$TRUST" --gate feature --level L3 >/dev/null 2>&1; RC=$?
assert_eq 0 "$RC" "--gate --level L3 passes at effective L3"
bash "$TRUST" --gate docs --level L3 >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "--gate --level L3 fails for a class at L1"
OUT="$(bash "$TRUST" --gate docs --level L1 2>&1)"; RC=$?
assert_eq 1 "$RC" "--level only takes L2 or L3"
assert_not_contains "$OUT" "Traceback" "a bad --level prints no traceback"
for k in $(seq 1 25); do python3 "$LEDGER" add --pr "$((100 + k))" --sha "5010$(printf '%036d' "$k")" --class solo >/dev/null; done
assert_eq L1 "$(col solo 7)" "solo suggestion stays L1 with a clean record"

# A revert always costs a level below the cap (caps apply before the drop).
rm -rf "$HOME/.agents/skills/zstack-fleet"
python3 "$LEDGER" add --pr 300 --sha "feed$(printf '%036d' 1)" --class feature >/dev/null
python3 "$LEDGER" flag --sha "feed$(printf '%036d' 1)" --reverted >/dev/null
assert_eq L1 "$(col feature 6)" "feature L3 without fleet plus a revert is effective L1"
bash "$TRUST" --gate feature >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "--gate feature fails after the revert"
python3 "$LEDGER" flag --sha "5010$(printf '%036d' 1)" --reverted >/dev/null
assert_eq L0 "$(col solo 6)" "solo L3 plus a revert is effective L0"

# Export then import into an empty state gives identical stats.
python3 "$LEDGER" export "$SANDBOX/ledger-export.jsonl" >/dev/null; RC=$?
assert_eq 0 "$RC" "export exits 0"
BEFORE="$(python3 "$LEDGER" stats)"
export ZSTACK_STATE_DIR="$SANDBOX/state2"
python3 "$LEDGER" import "$SANDBOX/ledger-export.jsonl" >/dev/null; RC=$?
assert_eq 0 "$RC" "import exits 0"
assert_eq "$BEFORE" "$(python3 "$LEDGER" stats)" "imported stats match"
python3 "$LEDGER" import "$SANDBOX/ledger-export.jsonl" >/dev/null
assert_eq "$BEFORE" "$(python3 "$LEDGER" stats)" "importing twice dedupes"
OUT="$(python3 "$LEDGER" import "$SANDBOX/nope.jsonl" 2>&1)"; RC=$?
assert_eq 1 "$RC" "importing a missing file fails"
assert_not_contains "$OUT" "Traceback" "missing import file prints no traceback"
OUT="$(ZSTACK_NOW=yesterday python3 "$LEDGER" add --pr 9 --sha abc9999 --class docs 2>&1)"; RC=$?
assert_eq 1 "$RC" "a bad ZSTACK_NOW fails"
assert_eq 1 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "a bad ZSTACK_NOW prints one line"

finish
