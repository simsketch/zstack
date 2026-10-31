#!/usr/bin/env bash
# zcheck.sh: run a check on a clean tree and record the result at HEAD.
#
#   zcheck.sh [--name <n>] [--no-count] [--min-tests <n>] -- <cmd...>
#   zcheck.sh [--name <n>] [--no-count] [--min-tests <n>] '<shell string>'
#   zcheck.sh --verify <sha> <name>...
#   zcheck.sh --list [<sha>]
#
# Refuses a dirty tree, untracked files included (exit 2). Writes
# $STATE/checks/<sha>/<name> as key=value lines: exit, tests (a number,
# `unknown` when no count is recognized, `n/a` with --no-count), clean
# (yes when the tree is still clean and HEAD unchanged after the run), time,
# cmd. The name defaults to a slug of the command.
#
# A recognized count below --min-tests (default 1) records exit=3 and exits 3
# ("ran zero tests"). A failing command records and returns its own exit code.
#
# --verify exits 0 only when every named record exists with exit=0,
# clean=yes and tests other than 0; else it prints one line per missing or
# failed name and exits 1.
#
# State dir: $ZSTACK_STATE_DIR, else <git common dir>/zstack.
set -u
PROG=zcheck
here="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$here/lib.sh"

usage() {
  sed -n '3,6p' "$0" | sed 's/^# //' >&2
  exit 2
}

state="$(zs_state_dir)" || exit 1
checks="$state/checks"

resolve_sha() {
  local s
  s="$(git rev-parse --verify --quiet "$1^{commit}" 2>/dev/null)" && { printf '%s\n' "$s"; return; }
  printf '%s\n' "$1"
}

# field <file> <key>
field() {
  sed -n "s/^$2=//p" "$1" | head -n 1
}

do_verify() {
  [ $# -ge 2 ] || usage
  local sha bad=0 n f e t c
  sha="$(resolve_sha "$1")"; shift
  for n in "$@"; do
    f="$checks/$sha/$n"
    if [ ! -f "$f" ]; then
      echo "missing: $n (no record at $sha)"; bad=1; continue
    fi
    e="$(field "$f" exit)"; t="$(field "$f" tests)"; c="$(field "$f" clean)"
    if [ "$e" != 0 ]; then
      echo "failed: $n (exit=$e)"; bad=1
    elif [ "$c" != yes ]; then
      echo "failed: $n (clean=$c)"; bad=1
    elif [ "$t" = 0 ]; then
      echo "failed: $n (tests=0)"; bad=1
    fi
  done
  return "$bad"
}

do_list() {
  local sha f
  if [ $# -ge 1 ]; then
    sha="$(resolve_sha "$1")"
  else
    sha="$(git rev-parse HEAD 2>/dev/null)" || zs_die "$PROG" "not inside a git repository"
  fi
  [ -d "$checks/$sha" ] || { echo "no checks recorded at $sha"; return 0; }
  echo "checks at $sha"
  for f in "$checks/$sha"/*; do
    [ -f "$f" ] || continue
    printf '  %-24s exit=%s tests=%s clean=%s time=%s\n' "$(basename "$f")" \
      "$(field "$f" exit)" "$(field "$f" tests)" "$(field "$f" clean)" "$(field "$f" time)"
  done
}

# Count tests in an output file. Prints a number, or nothing when no pattern
# is recognized. The first pattern that matches wins; its matches are summed.
count_tests() {
  python3 -I - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)
patterns = [
    r"Tests:.*?(\d+) total",
    r"Ran (\d+) tests?",
    r"^# pass (\d+)",
    r"(\d+) examples?,",
    r"(\d+) passed",
]
for p in patterns:
    found = re.findall(p, text, re.M)
    if found:
        print(sum(int(x) for x in found))
        sys.exit(0)
tap = re.findall(r"^ok \d+", text, re.M)
if tap:
    print(len(tap))
PY
}

is_clean() {
  [ -z "$(git status --porcelain --untracked-files=all 2>/dev/null)" ]
}

slug() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -c1-60)"
  s="${s%-}"
  [ -n "$s" ] || s=check
  printf '%s\n' "$s"
}

name="" count=yes min_tests=1
case "${1:-}" in
  --verify) shift; do_verify "$@"; exit $? ;;
  --list) shift; do_list "$@"; exit $? ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || usage; name="$2"; shift 2 ;;
    --no-count) count=no; shift ;;
    --min-tests) [ $# -ge 2 ] || usage; min_tests="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) usage ;;
    -*) usage ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || usage
case "$min_tests" in ''|*[!0-9]*) zs_die "$PROG" "--min-tests needs a whole number" ;; esac
case "$name" in */*|.*) zs_die "$PROG" "--name may not contain / or start with ." ;; esac

if [ $# -eq 1 ]; then
  cmd_text="$1"
  set -- bash -c "$1"
else
  cmd_text="$*"
fi
[ -n "$name" ] || name="$(slug "$cmd_text")"

git rev-parse --git-dir >/dev/null 2>&1 || zs_die "$PROG" "not inside a git repository"
if ! is_clean; then
  echo "$PROG: working tree is dirty (untracked files count); commit or stash first" >&2
  exit 2
fi
sha="$(git rev-parse HEAD)" || zs_die "$PROG" "no HEAD commit"

out="$(mktemp "${TMPDIR:-/tmp}/zcheck.XXXXXX")" || zs_die "$PROG" "cannot create a temp file"
trap 'rm -f "$out"' EXIT
"$@" 2>&1 | tee "$out"
rc=${PIPESTATUS[0]}

clean=yes
if ! is_clean || [ "$(git rev-parse HEAD)" != "$sha" ]; then
  clean=no
fi

if [ "$count" = no ]; then
  tests=n/a
else
  tests="$(count_tests "$out")"
  [ -n "$tests" ] || tests=unknown
fi

status=$rc
if [ "$rc" -eq 0 ] && [ "$count" = yes ] && [ "$tests" != unknown ] && [ "$tests" -lt "$min_tests" ]; then
  status=3
  if [ "$tests" -eq 0 ]; then
    echo "$PROG: $name ran zero tests" >&2
  else
    echo "$PROG: $name ran $tests tests, fewer than --min-tests $min_tests (counts as ran zero tests)" >&2
  fi
fi

mkdir -p "$checks/$sha" || zs_die "$PROG" "cannot create $checks/$sha"
tmp="$checks/$sha/.$name.tmp.$$"
{
  echo "exit=$status"
  echo "tests=$tests"
  echo "clean=$clean"
  echo "time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cmd=$(printf '%s' "$cmd_text" | tr '\n' ' ')"
} > "$tmp" || zs_die "$PROG" "cannot write $tmp"
mv "$tmp" "$checks/$sha/$name" || zs_die "$PROG" "cannot write $checks/$sha/$name"

echo "$PROG: recorded $name at ${sha:0:12}: exit=$status tests=$tests clean=$clean" >&2
[ "$clean" = yes ] || echo "$PROG: the tree changed during the run; this record will not verify" >&2
exit "$status"
