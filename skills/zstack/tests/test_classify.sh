#!/usr/bin/env bash
# Tests for classify.sh: riskiest class wins, unmatched is feature, claims only raise.
# shellcheck source-path=SCRIPTDIR source=helpers.sh
. "$(dirname "$0")/helpers.sh"
CLASSIFY="$ZT_SCRIPTS/classify.sh"

new_sandbox
F="$SANDBOX/files.txt"
cls() { printf '%s\n' "$@" > "$F"; bash "$CLASSIFY" --files "$F" ${CLAIM:+--claimed "$CLAIM"} 2>&1; }

CLAIM=""
assert_eq docs "$(cls docs/a.md)" "docs/a.md is docs"
assert_eq solo "$(cls docs/a.md db/migrations/1.sql)" "docs plus a migration is solo"
assert_eq feature "$(cls src/x.py)" "unmatched file is feature"
assert_eq feature "$(cls docs/a.md src/x.py)" "docs plus unmatched is feature"
assert_eq tests "$(cls tests/test_a.py src/app.test.ts)" "test paths are tests"
assert_eq docs "$(cls README.md)" "root markdown is docs"
assert_eq solo "$(cls .github/workflows/ci.yml)" "workflow change is solo"
assert_eq solo "$(cls infra/main.tf)" "terraform is solo"
assert_eq solo "$(cls services/auth/login.py)" "auth path is solo"
assert_eq solo "$(cls migrations/1.sql)" "root-level migrations is solo"
assert_eq solo "$(cls auth/x.py)" "root-level auth is solo"

CLAIM=docs
assert_eq solo "$(cls db/migrations/1.sql)" "--claimed docs never lowers solo"
assert_eq feature "$(cls src/x.py)" "--claimed docs never lowers feature"
CLAIM=solo
assert_eq solo "$(cls docs/a.md)" "--claimed solo raises docs to solo"
CLAIM=bogus
OUT="$(cls docs/a.md)"; RC=$?
check_not "unknown claimed class fails" [ "$RC" -eq 0 ]
assert_contains "$OUT" "unknown class" "unknown class is named"
CLAIM=""

# A custom conf is used in place of the defaults.
C="$SANDBOX/custom.conf"
printf '%s\n' '# custom' 'ui/** -> small-ui' 'label:hold -> solo' > "$C"
printf '%s\n' ui/button.tsx > "$F"
assert_eq small-ui "$(bash "$CLASSIFY" --files "$F" --conf "$C")" "custom conf rule applies"
printf '%s\n' 'ui/** -> huge' > "$C"
bash "$CLASSIFY" --files "$F" --conf "$C" >/dev/null 2>&1; RC=$?
check_not "conf with an unknown class fails" [ "$RC" -eq 0 ]
bash "$CLASSIFY" --files "$F" --conf "$SANDBOX/no-such.conf" >/dev/null 2>&1; RC=$?
check_not "a missing --conf file fails" [ "$RC" -eq 0 ]

# --init writes $STATE/classes.conf once, and it is then the default.
OUT="$(bash "$CLASSIFY" --init 2>&1)"; RC=$?
assert_eq 0 "$RC" "--init exits 0"
check "--init writes classes.conf" [ -f "$ZSTACK_STATE_DIR/classes.conf" ]
assert_contains "$(cat "$ZSTACK_STATE_DIR/classes.conf")" "# zstack defaults: keep" "--init writes the defaults header"
assert_contains "$(cat "$ZSTACK_STATE_DIR/classes.conf")" "**/migrations/** -> solo" "--init writes the solo rules"
bash "$CLASSIFY" --init >/dev/null 2>&1; RC=$?
check_not "--init refuses to overwrite" [ "$RC" -eq 0 ]
echo 'src/** -> small-ui' >> "$ZSTACK_STATE_DIR/classes.conf"
assert_eq small-ui "$(cls src/x.py)" "state classes.conf is the default conf"

# --pr reads files and labels through gh.
export ZSTACK_GH="$ZT_STUBS/gh"
cat > "$SANDBOX/gh/pr-view.json" <<'JSON'
{"files":[{"path":"docs/guide.md"}],"labels":[{"name":"hold"}]}
JSON
assert_eq solo "$(bash "$CLASSIFY" --pr 7 2>&1)" "--pr with a hold label is solo"
assert_contains "$(cat "$SANDBOX/gh/calls.log")" "pr view 7" "--pr calls gh pr view"
echo 1 > "$SANDBOX/gh/exit"
OUT="$(bash "$CLASSIFY" --pr 7 2>&1)"; RC=$?
check_not "--pr fails when gh fails" [ "$RC" -eq 0 ]
assert_not_contains "$OUT" "Traceback" "gh failure prints no traceback"
assert_eq 1 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "gh failure prints one line"
rm "$SANDBOX/gh/exit"

# --base diffs against a ref.
R="$SANDBOX/repo"; new_repo "$R"
( cd "$R" && git checkout -q -b work && mkdir -p db/migrations && echo x > db/migrations/2.sql \
  && git add . && git commit -q -m mig )
rm -f "$ZSTACK_STATE_DIR/classes.conf"
assert_eq solo "$(cd "$R" && bash "$CLASSIFY" --base "$(git -C "$R" rev-list --max-parents=0 HEAD)" 2>&1)" "--base finds the migration"

finish
