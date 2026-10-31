#!/usr/bin/env bash
# prepublish-grep.sh [--terms <file>] [path...]
#
# Scans files for things that must never ship in a public tree: secrets,
# absolute home paths, private email addresses and private terms (client or
# employer names) kept in a list outside the tree.
#
# Private terms come from the first of: --terms <file>, $ZSTACK_PRIVATE_TERMS_FILE,
# $ZSTACK_PRIVATE_TERMS (newline-separated list, for a CI secret).
# Terms format: one extended regex per line, '#' starts a comment line, blank
# lines ignored. Each term is matched as a whole word, case-insensitive. A line
# starting with 'case:' is matched case-sensitively (still whole-word).
#
# Exit 0 when clean, 1 with one 'file:line: <rule>' line per hit (the matched
# text is never printed), 2 on usage errors. Skips .git/ (and the .git file a worktree has) and binary files.
set -u

usage() { echo "usage: prepublish-grep.sh [--terms <file>] [path...]" >&2; exit 2; }

terms_file=""
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --terms) [ $# -ge 2 ] || usage; terms_file="$2"; shift 2 ;;
    --terms=*) terms_file="${1#--terms=}"; shift ;;
    -h|--help) usage ;;
    --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done ;;
    -*) usage ;;
    *) paths+=("$1"); shift ;;
  esac
done
[ ${#paths[@]} -gt 0 ] || paths=(".")

terms_text=""
if [ -n "$terms_file" ]; then
  [ -f "$terms_file" ] || { echo "prepublish-grep: terms file not found: $terms_file" >&2; exit 2; }
  terms_text="$(cat "$terms_file")"
elif [ -n "${ZSTACK_PRIVATE_TERMS_FILE:-}" ]; then
  [ -f "$ZSTACK_PRIVATE_TERMS_FILE" ] || { echo "prepublish-grep: terms file not found: $ZSTACK_PRIVATE_TERMS_FILE" >&2; exit 2; }
  terms_text="$(cat "$ZSTACK_PRIVATE_TERMS_FILE")"
elif [ -n "${ZSTACK_PRIVATE_TERMS:-}" ]; then
  terms_text="$ZSTACK_PRIVATE_TERMS"
fi

command -v python3 >/dev/null 2>&1 || { echo "prepublish-grep: python3 is required" >&2; exit 2; }

ZSTACK_TERMS_TEXT="$terms_text" exec python3 -I -c '
import os, re, sys

BUILTIN = [
    ("private-key", re.compile(r"-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----")),
    ("aws-access-key", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("github-token", re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}")),
    ("api-key", re.compile(r"sk-[A-Za-z0-9_-]{20,}")),
    ("slack-token", re.compile(r"xox[abpr]-")),
    ("home-path", re.compile(r"/Users/[a-z]")),
    ("home-path", re.compile(r"/home/[a-z]+/")),
]
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})")
ALLOWED_DOMAINS = ("example.com", "example.org", "users.noreply.github.com")
WORD = r"(?<![A-Za-z0-9_])(?:%s)(?![A-Za-z0-9_])"

terms = []
for raw in os.environ.get("ZSTACK_TERMS_TEXT", "").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    flags = re.IGNORECASE
    if line.startswith("case:"):
        line = line[len("case:"):].strip()
        flags = 0
        if not line:
            continue
    try:
        terms.append(re.compile(WORD % line, flags))
    except re.error:
        sys.stderr.write("prepublish-grep: invalid term pattern (line skipped)\n")

if not terms:
    print("note: no private term list; built-in checks only")

def allowed(domain):
    d = domain.lower()
    return any(d == a or d.endswith("." + a) for a in ALLOWED_DOMAINS)

def files(paths):
    for p in paths:
        if os.path.isfile(p):
            yield p
            continue
        for root, dirs, names in os.walk(p):
            dirs[:] = sorted(d for d in dirs if d != ".git")
            for n in sorted(n for n in names if n != ".git"):
                yield os.path.join(root, n)

hits = 0
for path in files(sys.argv[1:]):
    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError:
        continue
    if b"\0" in data[:8192]:
        continue
    text = data.decode("utf-8", errors="replace")
    shown = path[2:] if path.startswith("./") else path
    for no, line in enumerate(text.splitlines(), 1):
        rules = [name for name, rx in BUILTIN if rx.search(line)]
        if any(not allowed(m.group(1)) for m in EMAIL.finditer(line)):
            rules.append("email")
        if any(rx.search(line) for rx in terms):
            rules.append("private-term")
        seen = []
        for r in rules:
            if r not in seen:
                seen.append(r)
                print("%s:%d: %s" % (shown, no, r))
                hits += 1

if hits:
    print("prepublish-grep: %d hit(s)" % hits)
    sys.exit(1)
sys.exit(0)
' "${paths[@]}"
