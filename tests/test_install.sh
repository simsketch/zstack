#!/usr/bin/env bash
# Tests for install.sh using temp destinations.
# shellcheck source=tests/helpers.sh
. "$(dirname "$0")/helpers.sh"
INSTALL="$ZT_ROOT/install.sh"
export ZSTACK_SKIP_VALIDATE=1

t="$(zt_tmpdir)"
A="$t/agents"; C="$t/claude"
run_install() { OUT="$(bash "$INSTALL" --dest-agents "$A" --dest-claude "$C" "$@" 2>&1)"; RC=$?; }

run_install
assert_eq 0 "$RC" "first install exits 0"
assert_eq "$ZT_ROOT/skills/zstack" "$(readlink "$A/zstack")" "agents symlink points at skill"
assert_eq "$ZT_ROOT/skills/zstack" "$(readlink "$C/zstack")" "claude symlink points at skill"

run_install
assert_eq 0 "$RC" "second install exits 0"
assert_contains "$OUT" "already linked" "second install says already linked"

t2="$(zt_tmpdir)"
A="$t2/agents"; C="$t2/claude"
mkdir -p "$A/zstack" "$C"
echo keep > "$A/zstack/mine.txt"
run_install
assert_eq 2 "$RC" "real dir in the way exits 2"
assert_eq keep "$(cat "$A/zstack/mine.txt")" "real dir left untouched"
check_not "nothing linked after refusal" [ -e "$C/zstack" ]

t3="$(zt_tmpdir)"
A="$t3/agents"; C="$t3/claude"
mkdir -p "$A" "$C"
ln -s "$t3" "$A/zstack"
run_install
assert_eq 2 "$RC" "foreign symlink in the way exits 2"

t4="$(zt_tmpdir)"
A="$t4/agents"; C="$t4/claude"
run_install
mkdir -p "$t4/other"
ln -s "$t4/other" "$A/other-skill"
run_install --uninstall
assert_eq 0 "$RC" "uninstall exits 0"
check_not "uninstall removes agents link" [ -L "$A/zstack" ]
check_not "uninstall removes claude link" [ -L "$C/zstack" ]
check "uninstall keeps foreign symlink" [ -L "$A/other-skill" ]

t5="$(zt_tmpdir)"
A="$t5/agents"; C="$t5/claude"
mkdir -p "$A/zstack" "$C"
run_install --uninstall
assert_eq 0 "$RC" "uninstall with a real dir exits 0"
check "uninstall leaves a real dir" [ -d "$A/zstack" ]

finish
