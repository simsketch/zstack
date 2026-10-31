#!/usr/bin/env bash
# classify.sh: print a PR's class from its changed files and labels.
#
#   classify.sh [--files <file>|--base <ref>|--pr <n>] [--claimed <class>] [--conf <path>]
#   classify.sh --init
#
# Classes, lowest to riskiest: docs < tests < small-ui < feature < solo.
# Each file takes the riskiest class of every rule it matches; a file no rule
# matches counts as feature. The PR takes the riskiest class of its files and
# labels. --claimed can only raise the result, never lower it.
#
# Sources: --files <file> (one path per line, - for stdin), --base <ref>
# (git diff <ref>...HEAD), --pr <n> (files and labels via gh; when gh pr view
# lists 100 or more files, the full list comes from the paginated pulls/<n>/files
# API, and a failure there is an error rather than a partial answer). Default:
# --base with `base=` from the state config, else main.
#
# Rules: --conf <path>, else $STATE/classes.conf, else the shipped template
# (../templates/classes.conf), else the built-in defaults. Format, one per
# line: `<glob> -> <class>` or `label:<name> -> <class>`; `#` comments.
# Globs use fnmatch rules (`*` also crosses `/`), and `**/` also matches no
# directory at all, so `**/tests/**` matches `tests/a.py`.
#
# --init copies the template (or the built-in defaults) to $STATE/classes.conf
# and refuses to overwrite an existing file.
set -u
PROG=classify
here="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$here/lib.sh"
template="$here/../templates/classes.conf"

usage() {
  sed -n '4,5p' "$0" | sed 's/^# //' >&2
  exit 2
}

# The same default rules Task 3 ships in templates/classes.conf.
default_rules() {
  cat <<'CONF'
# zstack defaults: keep
# Riskiest matching class wins; unmatched files are feature.
# Classes: docs < tests < small-ui < feature < solo
docs/** -> docs
*.md -> docs
**/test/** -> tests
**/tests/** -> tests
**/*.test.* -> tests
**/*_test.* -> tests
**/migrations/** -> solo
**/migrate/** -> solo
.github/workflows/** -> solo
**/*.tf -> solo
**/infra/** -> solo
**/auth/** -> solo
**/security/** -> solo
**/payments/** -> solo
**/billing/** -> solo
label:security -> solo
label:hold -> solo

# Your rules go below. Removing a default above lowers the class of risky paths.
CONF
}

src="" src_arg="" claimed="" conf="" init=no
while [ $# -gt 0 ]; do
  case "$1" in
    --files|--base|--pr)
      [ $# -ge 2 ] || usage
      [ -z "$src" ] || zs_die "$PROG" "use one of --files, --base, --pr"
      src="${1#--}"; src_arg="$2"; shift 2 ;;
    --claimed) [ $# -ge 2 ] || usage; claimed="$2"; shift 2 ;;
    --conf) [ $# -ge 2 ] || usage; conf="$2"; shift 2 ;;
    --init) init=yes; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

if [ "$init" = yes ]; then
  state="$(zs_state_dir)" || exit 1
  dest="$state/classes.conf"
  [ ! -e "$dest" ] || zs_die "$PROG" "$dest already exists; edit it by hand"
  mkdir -p "$state" || zs_die "$PROG" "cannot create $state"
  if [ -f "$template" ]; then
    cp "$template" "$dest" || zs_die "$PROG" "cannot write $dest"
  else
    default_rules > "$dest" || zs_die "$PROG" "cannot write $dest"
  fi
  echo "wrote $dest"
  exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/zclassify.XXXXXX")" || zs_die "$PROG" "cannot create a temp dir"
trap 'rm -rf "$work"' EXIT

# Pick the rules file.
if [ -n "$conf" ]; then
  [ -f "$conf" ] || zs_die "$PROG" "conf not found: $conf"
else
  state_conf=""
  if state="$(zs_state_dir 2>/dev/null)"; then state_conf="$state/classes.conf"; fi
  if [ -n "$state_conf" ] && [ -f "$state_conf" ]; then
    conf="$state_conf"
  elif [ -f "$template" ]; then
    conf="$template"
  else
    conf="$work/defaults.conf"
    default_rules > "$conf"
  fi
fi

# Gather changed files (and labels, for --pr) as JSON or a plain list.
input="$work/input"
mode=list
case "$src" in
  files)
    if [ "$src_arg" = - ]; then cat > "$input"; else
      [ -f "$src_arg" ] || zs_die "$PROG" "files list not found: $src_arg"
      cp "$src_arg" "$input"
    fi ;;
  pr)
    case "$src_arg" in ''|*[!0-9]*) zs_die "$PROG" "--pr needs a PR number" ;; esac
    mode=json
    if ! zs_gh pr view "$src_arg" --json files,labels > "$input" 2> "$work/err"; then
      zs_die "$PROG" "gh pr view $src_arg failed: $(head -n 1 "$work/err")"
    fi
    # gh pr view returns at most 100 files; past that, read every page.
    n_files=$(python3 -I -c 'import json, sys
try:
    print(len((json.load(open(sys.argv[1])) or {}).get("files") or []))
except Exception:
    print(0)' "$input")
    if [ "$n_files" -ge 100 ]; then
      if ! zs_gh api --paginate "repos/{owner}/{repo}/pulls/$src_arg/files" --jq '.[].filename' \
          > "$work/more" 2> "$work/err"; then
        zs_die "$PROG" "PR $src_arg lists $n_files+ files and the full list could not be read: $(head -n 1 "$work/err")"
      fi
    fi ;;
  *)
    base="$src_arg"
    if [ -z "$base" ]; then base="$(zs_config_get base 2>/dev/null)" || base=main; fi
    git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 \
      || zs_die "$PROG" "base ref not found: $base"
    git diff --name-only "$base...HEAD" > "$input" 2> "$work/err" \
      || zs_die "$PROG" "git diff against $base failed: $(head -n 1 "$work/err")" ;;
esac

python3 -I - "$conf" "$input" "$mode" "$claimed" "$work/more" <<'PY'
import json, os, re, sys

conf_path, input_path, mode, claimed, more_path = sys.argv[1:6]
ORDER = ["docs", "tests", "small-ui", "feature", "solo"]
RANK = {c: i for i, c in enumerate(ORDER)}

def die(msg):
    print("classify: " + msg, file=sys.stderr)
    sys.exit(1)

def glob_regex(pat):
    out, i, n = [], 0, len(pat)
    while i < n:
        c = pat[i]
        if pat.startswith("**/", i):
            out.append("(?:.*/)?"); i += 3
        elif pat.startswith("**", i):
            out.append(".*"); i += 2
        elif c == "*":
            out.append(".*"); i += 1
        elif c == "?":
            out.append("."); i += 1
        elif c == "[":
            j = pat.find("]", i + 2 if i + 1 < n and pat[i + 1] in "!^" else i + 1)
            if j == -1:
                out.append(re.escape(c)); i += 1
            else:
                body = pat[i + 1:j]
                if body[:1] in ("!", "^"):
                    body = "^" + body[1:]
                out.append("[" + body.replace("\\", "\\\\") + "]"); i = j + 1
        else:
            out.append(re.escape(c)); i += 1
    return re.compile("".join(out) + r"\Z")

globs, labels = [], []
try:
    lines = open(conf_path, encoding="utf-8").read().splitlines()
except OSError as e:
    die("cannot read %s: %s" % (conf_path, e.strerror))
for num, raw in enumerate(lines, 1):
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if "->" not in line:
        die("%s:%d: expected '<glob> -> <class>'" % (conf_path, num))
    lhs, rhs = (p.strip() for p in line.rsplit("->", 1))
    if rhs not in RANK:
        die("%s:%d: unknown class '%s' (use %s)" % (conf_path, num, rhs, ", ".join(ORDER)))
    if lhs.startswith("label:"):
        labels.append((lhs[6:].strip(), rhs))
    else:
        globs.append((glob_regex(lhs), rhs))

if claimed and claimed not in RANK:
    die("unknown class '%s' (use %s)" % (claimed, ", ".join(ORDER)))

files, pr_labels = [], []
raw = open(input_path, encoding="utf-8", errors="replace").read()
if mode == "json":
    try:
        data = json.loads(raw or "{}")
        files = [f["path"] for f in data.get("files") or []]
        pr_labels = [l["name"] for l in data.get("labels") or []]
    except (ValueError, KeyError, TypeError, AttributeError):
        die("could not read gh pr view output")
    if os.path.isfile(more_path):
        more = open(more_path, encoding="utf-8", errors="replace").read().splitlines()
        files += [l.strip() for l in more if l.strip()]
else:
    files = [l.strip() for l in raw.splitlines() if l.strip()]

best = -1
for path in files:
    path = path[2:] if path.startswith("./") else path
    hits = [RANK[c] for rx, c in globs if rx.match(path)]
    best = max(best, max(hits) if hits else RANK["feature"])
for name in pr_labels:
    for want, c in labels:
        if name == want:
            best = max(best, RANK[c])
if best < 0:
    best = RANK["feature"]
if claimed:
    best = max(best, RANK[claimed])
print(ORDER[best])
PY
