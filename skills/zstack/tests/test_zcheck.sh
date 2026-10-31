#!/usr/bin/env bash
# Tests for zcheck.sh: clean-tree recording, test counts and --verify.
# shellcheck source-path=SCRIPTDIR source=helpers.sh
. "$(dirname "$0")/helpers.sh"
ZCHECK="$ZT_SCRIPTS/zcheck.sh"

new_sandbox
R="$SANDBOX/repo"
new_repo "$R"
cd "$R" || exit 1
SHA="$(git rev-parse HEAD)"
rec() { cat "$ZSTACK_STATE_DIR/checks/$SHA/$1" 2>/dev/null; }

# Dirty tree (untracked file) is refused.
echo x > untracked.txt
OUT="$(bash "$ZCHECK" -- echo "5 passed" 2>&1)"; RC=$?
assert_eq 2 "$RC" "untracked file refuses with exit 2"
assert_contains "$OUT" "dirty" "refusal names the dirty tree"
check_not "no record written for a dirty tree" [ -d "$ZSTACK_STATE_DIR/checks/$SHA" ]
rm untracked.txt

# Modified tracked file is refused too.
echo changed >> README.md
bash "$ZCHECK" -- true >/dev/null 2>&1; RC=$?
assert_eq 2 "$RC" "modified tracked file refuses with exit 2"
git checkout -q README.md

# Recognized count.
OUT="$(bash "$ZCHECK" --name unit -- echo "5 passed" 2>&1)"; RC=$?
assert_eq 0 "$RC" "5 passed exits 0"
assert_contains "$OUT" "5 passed" "command output is shown"
assert_contains "$(rec unit)" "tests=5" "records tests=5"
assert_contains "$(rec unit)" "exit=0" "records exit=0"
assert_contains "$(rec unit)" "clean=yes" "records clean=yes"
assert_contains "$(rec unit)" "cmd=echo 5 passed" "records the command"
assert_contains "$(rec unit)" "time=" "records the time"

# Zero tests fails.
OUT="$(bash "$ZCHECK" --name zero -- echo "0 passed" 2>&1)"; RC=$?
assert_eq 3 "$RC" "0 passed exits 3"
assert_contains "$OUT" "ran zero tests" "zero tests message"
assert_contains "$(rec zero)" "exit=3" "zero tests records exit=3"

# --min-tests raises the bar.
bash "$ZCHECK" --name few --min-tests 10 -- echo "Ran 4 tests" >/dev/null 2>&1; RC=$?
assert_eq 3 "$RC" "below --min-tests exits 3"

# Other count formats.
bash "$ZCHECK" --name jest -- printf 'Tests:       1 skipped, 7 passed, 8 total\n' >/dev/null 2>&1
assert_contains "$(rec jest)" "tests=8" "jest total parsed"
bash "$ZCHECK" --name tap -- printf 'ok 1 a\nok 2 b\nnot ok 3 c\n' >/dev/null 2>&1
assert_contains "$(rec tap)" "tests=2" "TAP ok lines counted"
bash "$ZCHECK" --name rspec -- echo "12 examples, 0 failures" >/dev/null 2>&1
assert_contains "$(rec rspec)" "tests=12" "rspec examples parsed"

# One quoted shell string; default name is a slug of the command.
bash "$ZCHECK" 'echo "3 passed" && true' >/dev/null 2>&1; RC=$?
assert_eq 0 "$RC" "quoted shell string runs"
assert_contains "$(rec echo-3-passed-true)" "tests=3" "default name is a slug of the command"

# Failing command records its exit code.
bash "$ZCHECK" --name broken -- sh -c 'echo "2 passed"; exit 4' >/dev/null 2>&1; RC=$?
assert_eq 4 "$RC" "failing command passes its exit code through"
assert_contains "$(rec broken)" "exit=4" "failing command records its exit code"

# --no-count records n/a and verifies.
bash "$ZCHECK" --name lint --no-count -- true >/dev/null 2>&1; RC=$?
assert_eq 0 "$RC" "--no-count exits 0"
assert_contains "$(rec lint)" "tests=n/a" "--no-count records tests=n/a"

# No recognizable count records unknown and still passes.
bash "$ZCHECK" --name typecheck -- echo "all good" >/dev/null 2>&1; RC=$?
assert_eq 0 "$RC" "unrecognized output exits 0"
assert_contains "$(rec typecheck)" "tests=unknown" "unrecognized output records tests=unknown"

# --verify.
OUT="$(bash "$ZCHECK" --verify "$SHA" unit lint typecheck 2>&1)"; RC=$?
assert_eq 0 "$RC" "--verify passes for good records"
OUT="$(bash "$ZCHECK" --verify "$SHA" unit zero missing broken 2>&1)"; RC=$?
assert_eq 1 "$RC" "--verify fails when a record is bad or missing"
assert_contains "$OUT" "zero" "--verify names the zero-test check"
assert_contains "$OUT" "missing" "--verify names the missing check"
assert_contains "$OUT" "broken" "--verify names the failed check"
assert_not_contains "$OUT" "unit" "--verify does not name the good check"

# A record missing a field does not verify.
printf 'exit=0\nclean=yes\n' > "$ZSTACK_STATE_DIR/checks/$SHA/partial"
OUT="$(bash "$ZCHECK" --verify "$SHA" partial 2>&1)"; RC=$?
assert_eq 1 "$RC" "--verify fails an incomplete record"
assert_contains "$OUT" "incomplete" "--verify says the record is incomplete"

# A tree change during the run records clean=no and does not verify.
bash "$ZCHECK" --name dirtier -- sh -c 'echo "1 passed"; echo x > during.txt' >/dev/null 2>&1
assert_contains "$(rec dirtier)" "clean=no" "tree change during the run records clean=no"
bash "$ZCHECK" --verify "$SHA" dirtier >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "--verify fails a clean=no record"
rm -f during.txt

# --list.
OUT="$(bash "$ZCHECK" --list 2>&1)"
assert_contains "$OUT" "unit" "--list shows records at HEAD"
assert_contains "$OUT" "lint" "--list shows the n/a record"

# A commit after the check: the new sha has no records.
echo more >> README.md
git commit -q -am more
NEW="$(git rev-parse HEAD)"
bash "$ZCHECK" --verify "$NEW" unit >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "--verify at a newer sha fails"

# Default state dir is <git-common-dir>/zstack and stays out of git status.
unset ZSTACK_STATE_DIR
bash "$ZCHECK" --name unit -- echo "1 passed" >/dev/null 2>&1
check "default state dir under .git/zstack" [ -f "$R/.git/zstack/checks/$NEW/unit" ]
assert_eq "" "$(git status --porcelain)" "state dir does not dirty the tree"

finish
