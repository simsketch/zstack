#!/usr/bin/env bash
# check-manifests.sh [repo-root]
#
# Checks that every harness manifest in the repo agrees with the skills tree:
#   1. Each manifest parses as JSON: plugin.json, .claude-plugin/*.json,
#      .codex-plugin/plugin.json, .agents/plugins/marketplace.json,
#      gemini-extension.json, package.json, hooks/*.json.
#   2. Every skill path a manifest names exists, holds SKILL.md, and that
#      SKILL.md's frontmatter `name` equals the folder name. Same for every
#      folder under skills/.
#   3. Every manifest version equals metadata.version in skills/zstack/SKILL.md.
#   4. Hook commands point at scripts that exist and are executable.
#   5. Playbook catalog (only when skills/zstack/playbooks/ exists): every
#      playbooks/<name>.md is named in SKILL.md (as `<name>` or
#      playbooks/<name>.md), and every entry in SKILL.md's catalog exists as a
#      file. The catalog is the section under the first heading containing
#      "playbook" (and not "principle"); each table row or list item there
#      contributes its first backticked token as a playbook name.
#   6. Each skill passes the Agent Skills validator: `agentskills` on PATH,
#      else `uvx --from skills-ref agentskills`, else a stdlib frontmatter
#      check. ZSTACK_VALIDATOR=stdlib forces the stdlib check.
#
# Exit 0 when everything passes, 1 with one line per problem.
set -u

root="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -d "$root/skills" ] || { echo "check-manifests: no skills/ under $root" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "check-manifests: python3 is required" >&2; exit 1; }

status=0
python3 -I - "$root" <<'PY' || status=1
import json, os, re, sys

root = sys.argv[1]
problems = []

def rel(p):
    return os.path.relpath(p, root)

def frontmatter(path):
    """Return (keys dict of top-level scalar values, metadata dict, raw key list) or None."""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return None
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end < 0:
        return None
    lines = text[4:end].splitlines()
    top, meta, order = {}, {}, []
    i, cur = 0, None
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            order.append(key)
            cur = key
            if val in (">", "|", ">-", "|-", ">+", "|+"):
                parts = []
                i += 1
                while i < len(lines) and (lines[i].startswith(" ") or not lines[i].strip()):
                    parts.append(lines[i].strip())
                    i += 1
                top[key] = " ".join(p for p in parts if p)
                continue
            top[key] = unquote(val)
        else:
            m = re.match(r"^\s+([A-Za-z0-9_-]+):\s*(.*)$", line)
            if m and cur == "metadata":
                meta[m.group(1)] = unquote(m.group(2).strip())
        i += 1
    return top, meta, order

def unquote(v):
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v

def check_skill_dir(path, origin):
    if not os.path.isdir(path):
        problems.append("%s: skill path %s does not exist" % (origin, rel(path)))
        return
    skill_md = os.path.join(path, "SKILL.md")
    if not os.path.isfile(skill_md):
        problems.append("%s: %s has no SKILL.md" % (origin, rel(path)))
        return
    fm = frontmatter(skill_md)
    if fm is None:
        problems.append("%s: no frontmatter" % rel(skill_md))
        return
    name = fm[0].get("name", "")
    folder = os.path.basename(os.path.normpath(path))
    if name != folder:
        problems.append("%s: frontmatter name '%s' does not match folder '%s'" % (rel(skill_md), name, folder))

def load(relpath):
    p = os.path.join(root, relpath)
    if not os.path.isfile(p):
        problems.append("%s: missing" % relpath)
        return None
    try:
        with open(p, encoding="utf-8") as fh:
            return json.load(fh)
    except (ValueError, OSError) as e:
        problems.append("%s: invalid JSON (%s)" % (relpath, e))
        return None

# Skills tree
skills_root = os.path.join(root, "skills")
for d in sorted(os.listdir(skills_root)):
    p = os.path.join(skills_root, d)
    if os.path.isdir(p):
        check_skill_dir(p, "skills/")

core_md = os.path.join(skills_root, "zstack", "SKILL.md")
fm = frontmatter(core_md)
version = fm[1].get("version") if fm else None
if not version:
    problems.append("skills/zstack/SKILL.md: metadata.version missing")

def want_version(origin, v):
    if version and v != version:
        problems.append("%s: version %s does not match SKILL.md metadata.version %s" % (origin, v, version))

def resolve(path):
    return os.path.normpath(os.path.join(root, path))

manifests = ["plugin.json", ".codex-plugin/plugin.json", ".agents/plugins/marketplace.json",
             "gemini-extension.json", "package.json", "hooks/hooks.json", "hooks/codex-hooks.json"]
cdir = os.path.join(root, ".claude-plugin")
if os.path.isdir(cdir):
    manifests += sorted(".claude-plugin/" + f for f in os.listdir(cdir) if f.endswith(".json"))
else:
    problems.append(".claude-plugin/: missing")

data = {}
for m in manifests:
    obj = load(m)
    if obj is not None:
        data[m] = obj

for m in ("plugin.json", ".claude-plugin/plugin.json", ".codex-plugin/plugin.json",
          "gemini-extension.json", "package.json"):
    if m in data:
        want_version(m, data[m].get("version"))
        if data[m].get("name") != "zstack":
            problems.append("%s: name should be zstack" % m)

mk = data.get(".claude-plugin/marketplace.json")
if mk:
    for pl in mk.get("plugins", []):
        want_version(".claude-plugin/marketplace.json plugins[%s]" % pl.get("name"), pl.get("version"))
        src = pl.get("source")
        if isinstance(src, str) and not os.path.isdir(resolve(src)):
            problems.append(".claude-plugin/marketplace.json: source %s does not exist" % src)

amk = data.get(".agents/plugins/marketplace.json")
if amk:
    for pl in amk.get("plugins", []):
        src = pl.get("source", {})
        path = src.get("path") if isinstance(src, dict) else src
        if not path or not os.path.isdir(resolve(path)):
            problems.append(".agents/plugins/marketplace.json: source path %s does not exist" % path)

cx = data.get(".codex-plugin/plugin.json")
if cx:
    sk = cx.get("skills")
    if sk:
        p = resolve(sk)
        if not os.path.isdir(p):
            problems.append(".codex-plugin/plugin.json: skills path %s does not exist" % sk)
        else:
            for d in sorted(os.listdir(p)):
                if os.path.isdir(os.path.join(p, d)):
                    check_skill_dir(os.path.join(p, d), ".codex-plugin/plugin.json")
    hk = cx.get("hooks")
    if isinstance(hk, str) and not os.path.isfile(resolve(hk)):
        problems.append(".codex-plugin/plugin.json: hooks file %s does not exist" % hk)

pkg = data.get("package.json")
if pkg:
    pi = pkg.get("pi")
    if not isinstance(pi, dict) or not pi.get("skills"):
        problems.append("package.json: pi.skills missing")
    else:
        for s in pi["skills"]:
            check_skill_dir(resolve(s), "package.json pi.skills")

gem = data.get("gemini-extension.json")
if gem:
    ctx = gem.get("contextFileName")
    if ctx and not os.path.isfile(resolve(ctx)):
        problems.append("gemini-extension.json: contextFileName %s does not exist" % ctx)

for hf in ("hooks/hooks.json", "hooks/codex-hooks.json"):
    h = data.get(hf)
    if not h:
        continue
    for event, groups in h.get("hooks", {}).items():
        for g in groups:
            for hook in g.get("hooks", []):
                cmd = hook.get("command", "")
                m = re.search(r"\}/([^\"\s]+)", cmd)
                if hook.get("type") == "command" and m:
                    script = os.path.join(root, m.group(1))
                    if not os.path.isfile(script):
                        problems.append("%s: %s hook script %s does not exist" % (hf, event, m.group(1)))
                    elif not os.access(script, os.X_OK):
                        problems.append("%s: %s hook script %s is not executable" % (hf, event, m.group(1)))

# Playbook catalog
pb_dir = os.path.join(skills_root, "zstack", "playbooks")
if not os.path.isdir(pb_dir):
    print("skip: playbook catalog check (skills/zstack/playbooks/ does not exist yet)")
else:
    body = open(core_md, encoding="utf-8").read()
    files = sorted(f[:-3] for f in os.listdir(pb_dir) if f.endswith(".md"))
    for name in files:
        if ("`%s`" % name) not in body and ("playbooks/%s.md" % name) not in body:
            problems.append("skills/zstack/SKILL.md: playbook %s (playbooks/%s.md) is not named" % (name, name))
    catalog, in_cat, level = [], False, 0
    for line in body.splitlines():
        h = re.match(r"^(#+)\s+(.*)$", line)
        if h:
            if in_cat and len(h.group(1)) <= level:
                break
            t = h.group(2).lower()
            if not in_cat and "playbook" in t and "principle" not in t:
                in_cat, level = True, len(h.group(1))
            continue
        if in_cat and re.match(r"^\s*(\||[-*+]\s|\d+\.\s)", line):
            tok = re.search(r"`([^`]+)`", line)
            if tok:
                name = tok.group(1).strip()
                name = re.sub(r"^playbooks/", "", name)
                name = re.sub(r"\.md$", "", name)
                catalog.append(name)
    if not catalog:
        problems.append("skills/zstack/SKILL.md: playbooks/ exists but no playbook catalog section was found")
    for name in catalog:
        if name not in files:
            problems.append("skills/zstack/SKILL.md: catalog names playbook %s but playbooks/%s.md does not exist" % (name, name))

for p in problems:
    print("FAIL " + p)
sys.exit(1 if problems else 0)
PY

# Agent Skills validation, one skill at a time.
validator=()
if [ "${ZSTACK_VALIDATOR:-}" != stdlib ]; then
  if command -v agentskills >/dev/null 2>&1; then
    validator=(agentskills)
  elif command -v uvx >/dev/null 2>&1; then
    validator=(uvx --quiet --from skills-ref agentskills)
  fi
fi

for d in "$root"/skills/*/; do
  [ -f "${d}SKILL.md" ] || continue
  if [ ${#validator[@]} -gt 0 ]; then
    if ! out="$("${validator[@]}" validate "${d%/}" 2>&1)"; then
      printf '%s\n' "$out" | sed 's/^/  /'
      echo "FAIL skills/$(basename "$d"): Agent Skills validator failed"
      status=1
    fi
  else
    python3 -I - "${d%/}" <<'PY' || status=1
import os, re, sys
path = sys.argv[1]
folder = os.path.basename(path)
text = open(os.path.join(path, "SKILL.md"), encoding="utf-8").read()
bad = []
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not m:
    bad.append("no frontmatter")
    keys, vals = [], {}
else:
    keys, vals, lines = [], {}, m.group(1).splitlines()
    for i, line in enumerate(lines):
        k = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if k:
            keys.append(k.group(1))
            v = k.group(2).strip()
            if v in (">", "|", ">-", "|-"):
                cont = []
                for nxt in lines[i + 1:]:
                    if not nxt.startswith(" "):
                        break
                    cont.append(nxt.strip())
                v = " ".join(cont).strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            vals[k.group(1)] = v
allowed = {"name", "description", "license", "compatibility", "metadata"}
for k in keys:
    if k not in allowed:
        bad.append("frontmatter key '%s' is not allowed" % k)
name = vals.get("name", "")
if name != folder:
    bad.append("name '%s' does not match folder '%s'" % (name, folder))
if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name) or len(name) > 64:
    bad.append("name '%s' must be lowercase letters, digits and single hyphens, at most 64 chars" % name)
desc = vals.get("description", "")
if not 1 <= len(desc) <= 1024:
    bad.append("description must be 1-1024 characters (got %d)" % len(desc))
for b in bad:
    print("FAIL skills/%s: %s" % (folder, b))
sys.exit(1 if bad else 0)
PY
  fi
done

if [ "$status" -eq 0 ]; then
  echo "check-manifests: OK"
fi
exit "$status"
