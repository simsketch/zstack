#!/usr/bin/env bash
# Tests for scripts/prepublish-grep.sh. Fixture strings that look like secrets
# or home paths are assembled at runtime so this file itself stays clean.
# shellcheck source=tests/helpers.sh
. "$(dirname "$0")/helpers.sh"
GREP="$ZT_ROOT/scripts/prepublish-grep.sh"
unset ZSTACK_PRIVATE_TERMS ZSTACK_PRIVATE_TERMS_FILE

# run_grep <dir> [args...]: sets OUT and RC
run_grep() {
  local d="$1"; shift
  OUT="$(bash "$GREP" "$@" "$d" 2>&1)"; RC=$?
}

fixture() { # fixture <content>: new dir with a.txt holding <content>
  local d; d="$(zt_tmpdir)"
  printf '%s\n' "$1" > "$d/a.txt"
  printf '%s' "$d"
}

key="AKIA""ABCDEFGHIJKLMNOP"
d="$(fixture "aws = $key")"
run_grep "$d"
assert_eq 1 "$RC" "fake AWS key fails"
assert_contains "$OUT" "a.txt:1: aws-access-key" "AWS hit names file, line and rule"
assert_not_contains "$OUT" "$key" "AWS key is masked in output"
assert_contains "$OUT" "note: no private term list; built-in checks only" "note when no terms"

home="/""Users/someone/x"
d="$(fixture "path $home")"
run_grep "$d"
assert_eq 1 "$RC" "absolute home path fails"

real="someone@""gmail.com"
d="$(fixture "mail $real now")"
run_grep "$d"
assert_eq 1 "$RC" "private email fails"
assert_not_contains "$OUT" "$real" "email is masked in output"

d="$(fixture "contact dev@example.com or 1+me@users.noreply.github.com")"
run_grep "$d"
assert_eq 0 "$RC" "allowlisted emails pass"

d="$(fixture "dev@acme.test bob@home.example x@y.invalid a@b.localhost c@mail.example.net")"
run_grep "$d"
assert_eq 0 "$RC" "reserved test and documentation domains pass"

d="$(fixture "dev@""acme.testing.com")"
run_grep "$d"
assert_eq 1 "$RC" "a real domain that only contains a reserved word fails"

d="$(fixture "git remote add origin git@github.com:other-org/tool.git")"
run_grep "$d"
assert_eq 0 "$RC" "SSH git remote is not an email"

d="$(fixture "ping git@""gmail.com today")"
run_grep "$d"
assert_eq 1 "$RC" "a plain git@ address at a real domain still fails"

d="$(fixture "origin git@github.com:org/repo.git and $real")"
run_grep "$d"
assert_eq 1 "$RC" "a real address next to an SSH remote still fails"

rterms="$(zt_tmpdir)/terms.txt"
printf 'acme\n' > "$rterms"
d="$(fixture "dev@acme.test")"
run_grep "$d" --terms "$rterms"
assert_eq 1 "$RC" "a private term inside a reserved-domain address still fails"
assert_contains "$OUT" "private-term" "reserved-domain address still gets the term check"

d="$(fixture "clean text only")"
mkdir -p "$d/.git"; printf 'aws = %s\n' "$key" > "$d/.git/config"
run_grep "$d"
assert_eq 0 "$RC" ".git/ is skipped"

terms="$(zt_tmpdir)/terms.txt"
printf '# private names\nacme\n\n' > "$terms"
d="$(fixture "Built for ACME last year")"
run_grep "$d" --terms "$terms"
assert_eq 1 "$RC" "terms-file word fails case-insensitively"
assert_contains "$OUT" "private-term" "term hit uses private-term rule"
assert_not_contains "$OUT" "ACME" "term is masked in output"
assert_not_contains "$OUT" "note: no private term list" "no note when terms given"

d="$(fixture "the acmeville fair")"
run_grep "$d" --terms "$terms"
assert_eq 0 "$RC" "substring inside a longer word passes"

d="$(fixture "Built for ACME")"
OUT="$(ZSTACK_PRIVATE_TERMS_FILE="$terms" bash "$GREP" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "ZSTACK_PRIVATE_TERMS_FILE is read"
OUT="$(ZSTACK_PRIVATE_TERMS="$(printf 'zeta\nacme')" bash "$GREP" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "ZSTACK_PRIVATE_TERMS newline list is read"
OUT="$(ZSTACK_PRIVATE_TERMS="" bash "$GREP" "$d" 2>&1)"; RC=$?
assert_eq 0 "$RC" "empty ZSTACK_PRIVATE_TERMS means built-in checks only"
assert_contains "$OUT" "note: no private term list" "note when terms env is empty"

# The term is split so this file passes the real private list too.
cterm="Key""Ring"; lterm="key""ring"
cterms="$(zt_tmpdir)/terms.txt"
printf 'case:%s\n' "$cterm" > "$cterms"
d="$(fixture "the $cterm app")"
run_grep "$d" --terms "$cterms"
assert_eq 1 "$RC" "case: term matches exact case"
d="$(fixture "store it in the gh $lterm")"
run_grep "$d" --terms "$cterms"
assert_eq 0 "$RC" "case: term ignores other casing"

ghtok="ghp_""abcdefghijklmnopqrstuvwxyz0123456789"
d="$(fixture "token $ghtok")"
run_grep "$d"
assert_eq 1 "$RC" "GitHub token fails"
pk="-----BEGIN ""RSA PRIVATE KEY-----"
d="$(fixture "$pk")"
run_grep "$d"
assert_eq 1 "$RC" "private key header fails"

OUT="$(bash "$GREP" "$ZT_ROOT" 2>&1)"; RC=$?
assert_eq 0 "$RC" "repo tree itself passes built-in checks"

finish
