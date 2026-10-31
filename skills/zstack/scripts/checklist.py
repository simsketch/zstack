#!/usr/bin/env python3
"""checklist.py: build the manual-test checklist from merged PRs, and record results.

  checklist.py generate [--since <ISO>] [--repo <owner/name>] [--from-json <file>] [--out <dir>]
  checklist.py record <file> [--repo <owner/name>] [--dry-run]

generate lists PRs merged since --since (default: when the last checklist was
generated, else 24 hours ago) through gh, plus open issues labelled
manual-verify, and parses each one's "How to test" block (Environment,
Platform, Screen or Endpoint, Steps, Expected). Loose blocks are accepted:
bullets, bold labels, lowercase headings, missing fields. It writes
checklist-<YYYY-MM-DD>.md (default dir $STATE/checklists/) with one section
per environment, a "No test steps" list for PRs without usable steps, the
repo's smoke list from $STATE/smoke.md, and "Candidate journey tests": items
seen on 3 or more checklists. History lives in $STATE/checklists/history.jsonl.
--from-json reads a gh-style JSON list of PRs (or {"prs": [...], "issues": [...]})
in place of calling gh.

record reads a filled-in checklist. For each item marked [x] with
`result: pass|fail <note>`, it comments on the PR (gh pr comment <n> --body)
or issue, and prints `open bug: ...` for each failure. --dry-run prints the
gh commands instead of running them.

Exit 1 with one line when gh fails or is missing. ZSTACK_GH overrides gh,
ZSTACK_STATE_DIR the state dir, ZSTACK_NOW the current time (ISO, for tests).
"""
import argparse
import datetime as dt
import json
import os
import re
import shlex
import subprocess
import sys

PROG = "checklist"
CANDIDATE_MIN = 3
PR_FIELDS = "number,title,body,mergedAt,url"


class Fail(Exception):
    """A one-line, user-facing error."""


# ---------- environment ----------

def state_dir():
    env = os.environ.get("ZSTACK_STATE_DIR")
    if env:
        return env
    try:
        out = subprocess.run(["git", "rev-parse", "--git-common-dir"],
                             capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        raise Fail("not inside a git repository (set ZSTACK_STATE_DIR to use another state dir)")
    return os.path.join(os.path.realpath(out), "zstack")


def parse_time(value):
    if not value:
        return None
    v = value.strip().replace("Z", "+00:00")
    try:
        t = dt.datetime.fromisoformat(v)
    except ValueError:
        try:
            t = dt.datetime.combine(dt.date.fromisoformat(v), dt.time())
        except ValueError:
            return None
    if t.tzinfo is None:
        t = t.replace(tzinfo=dt.timezone.utc)
    return t.astimezone(dt.timezone.utc)


def now():
    env = os.environ.get("ZSTACK_NOW")
    if env:
        t = parse_time(env)
        if t is None:
            raise Fail("ZSTACK_NOW is not an ISO time: %s" % env)
        return t
    return dt.datetime.now(dt.timezone.utc)


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def one_line(text):
    return " ".join(str(text).split())


def gh(args):
    cmd = [os.environ.get("ZSTACK_GH") or "gh"] + args
    try:
        res = subprocess.run(cmd, capture_output=True, text=True)
    except OSError:
        raise Fail("gh not found or not runnable (install gh or set ZSTACK_GH)")
    if res.returncode != 0:
        lines = [l for l in res.stderr.splitlines() if l.strip()]
        why = lines[0].strip() if lines else "exit %d" % res.returncode
        raise Fail("gh %s failed: %s" % (" ".join(args[:2]), why))
    return res.stdout


def gh_json(args):
    out = gh(args)
    if not out.strip():
        return []
    try:
        return json.loads(out)
    except ValueError:
        raise Fail("gh %s returned output that is not JSON" % " ".join(args[:2]))


# ---------- parsing "How to test" ----------

LABELS = {
    "environment": "env", "env": "env",
    "platform": "platform",
    "screen": "screen", "page": "screen",
    "endpoint": "endpoint", "route": "endpoint", "url": "endpoint",
    "steps": "steps", "step": "steps", "steps to test": "steps",
    "expected": "expected", "expected result": "expected",
    "expected outcome": "expected", "expected behavior": "expected",
}
HEADING = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
BLOCK_HEADING = re.compile(r"^\s{0,3}(#{1,6})\s*how\s+to\s+test\b", re.I)
BOLD_BLOCK = re.compile(r"^\s*(\*\*|__)\s*how\s+to\s+test\s*:?\s*(\*\*|__)\s*:?\s*$", re.I)
BULLET = re.compile(r"^\s*[-*+]\s+(?:\[[ xX]\]\s+)?(.*)$")
NUMBERED = re.compile(r"^\s*(\d+)[.)]\s+(.*)$")
LABEL_IN_BOLD = re.compile(r"^(?:\*\*|__)\s*([A-Za-z][A-Za-z ]*?)\s*:\s*(?:\*\*|__)\s*(.*)$")
LABEL_PLAIN = re.compile(r"^(?:\*\*|__)?\s*([A-Za-z][A-Za-z ]*?)\s*(?:\*\*|__)?\s*:\s*(.*)$")
LABEL_BARE = re.compile(r"^(?:\*\*|__)?\s*([A-Za-z][A-Za-z ]*?)\s*(?:\*\*|__)?\s*:?\s*$")


def find_block(body):
    lines = (body or "").replace("\r\n", "\n").split("\n")
    for i, line in enumerate(lines):
        m = BLOCK_HEADING.match(line)
        level = len(m.group(1)) if m else (7 if BOLD_BLOCK.match(line) else 0)
        if not level:
            continue
        block = []
        for nxt in lines[i + 1:]:
            h = HEADING.match(nxt)
            if h and len(h.group(1)) <= level:
                break
            block.append(nxt)
        return block
    return None


def match_label(line):
    """Return (field, value) when the line is a field label, else None."""
    text = line.strip()
    was_heading = False
    h = HEADING.match(text)
    if h:
        text, was_heading = h.group(2), True
    else:
        b = BULLET.match(text)
        if b:
            text = b.group(1)
    for rx in (LABEL_IN_BOLD, LABEL_PLAIN):
        m = rx.match(text)
        if m and m.group(1).strip().lower() in LABELS:
            return LABELS[m.group(1).strip().lower()], m.group(2).strip()
    m = LABEL_BARE.match(text)
    if m and m.group(1).strip().lower() in LABELS and (was_heading or "**" in text or "__" in text):
        return LABELS[m.group(1).strip().lower()], ""
    return None


def clean(text):
    return one_line(text.replace("**", "").replace("`", ""))


def parse_block(block):
    fields = {"env": "", "platform": "", "screen": "", "endpoint": "", "steps": [], "expected": ""}
    current = None
    for line in block:
        if not line.strip():
            continue
        lab = match_label(line)
        if lab:
            current, value = lab
            if current == "steps":
                if value:
                    fields["steps"].append(clean(value))
            elif value:
                fields[current] = clean(value)
            continue
        n, b = NUMBERED.match(line), BULLET.match(line)
        if current in (None, "steps") and (n or b):
            fields["steps"].append(clean("%s. %s" % (n.group(1), n.group(2)) if n else b.group(1)))
            current = "steps"
        elif current == "steps":
            fields["steps"].append(clean(line))
        elif current in ("expected", "screen", "endpoint", "env", "platform"):
            text = clean(b.group(1) if b else (n.group(2) if n else line))
            fields[current] = (fields[current] + " " + text).strip()
    return fields


def make_item(kind, obj):
    block = find_block(obj.get("body"))
    base = {"kind": kind, "number": obj.get("number"), "title": one_line(obj.get("title") or "")}
    if block is None:
        return None, dict(base, why="no How to test block")
    f = parse_block(block)
    if not f["steps"]:
        return None, dict(base, why="How to test block has no steps")
    return dict(base,
                env=f["env"] or "unspecified environment",
                platform=f["platform"],
                screen=f["screen"] or f["endpoint"] or "(screen not given)",
                steps="; ".join(f["steps"]),
                expected=f["expected"] or "(not given)"), None


def item_key(it):
    return "|".join(x.lower() for x in (it["env"], it["platform"], it["screen"], it["steps"], it["expected"]))


def ref(kind, number):
    return "%s #%s" % ("PR" if kind == "pr" else "Issue", number)


# ---------- generate ----------

def history_path():
    return os.path.join(state_dir(), "checklists", "history.jsonl")


def read_history():
    path = history_path()
    if not os.path.exists(path):
        return []
    out = []
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    try:
                        out.append(json.loads(line))
                    except ValueError:
                        continue
    except OSError as e:
        raise Fail("cannot read %s: %s" % (path, e.strerror))
    return out


def write_atomic(path, text):
    d = os.path.dirname(path) or "."
    try:
        os.makedirs(d, exist_ok=True)
        tmp = os.path.join(d, ".%s.tmp.%d" % (os.path.basename(path), os.getpid()))
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except OSError as e:
        raise Fail("cannot write %s: %s" % (path, e.strerror))


def load_sources(a, since):
    if a.from_json:
        try:
            with open(a.from_json, encoding="utf-8") as fh:
                data = json.load(fh)
        except OSError as e:
            raise Fail("cannot read %s: %s" % (a.from_json, e.strerror))
        except ValueError:
            raise Fail("%s is not valid JSON" % a.from_json)
        if isinstance(data, dict):
            return data.get("prs") or [], data.get("issues") or []
        return data, []
    repo = ["--repo", a.repo] if a.repo else []
    prs = gh_json(["pr", "list", "--state", "merged", "--search", "merged:>=%s" % iso(since),
                   "--json", PR_FIELDS, "--limit", "200"] + repo)
    issues = gh_json(["issue", "list", "--label", "manual-verify", "--state", "open",
                      "--json", "number,title,body,url", "--limit", "100"] + repo)
    return prs, issues


def smoke_lines():
    path = os.path.join(state_dir(), "smoke.md")
    if not os.path.exists(path):
        return ["- (no smoke list yet: add `- [ ] <journey>: <steps> -> <expected>` lines to %s)" % path]
    out = []
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError as e:
        raise Fail("cannot read %s: %s" % (path, e.strerror))
    for line in lines:
        m = re.match(r"^\s*[-*+]\s+(?:\[[ xX]\]\s+)?(.*)$", line)
        if not m or not m.group(1).strip():
            continue
        text = re.sub(r"\s+result:.*$", "", m.group(1).strip())
        out.append("- [ ] %s  result:" % text)
    return out or ["- (smoke list at %s has no items)" % path]


def cmd_generate(a):
    current = now()
    history = read_history()
    if a.since:
        since = parse_time(a.since)
        if since is None:
            raise Fail("--since is not an ISO date or time: %s" % a.since)
    else:
        stamps = [parse_time(h.get("ts")) for h in history]
        stamps = [s for s in stamps if s is not None]
        since = max(stamps) if stamps else current - dt.timedelta(hours=24)

    prs, issues = load_sources(a, since)
    items, missing = [], []
    for kind, objs in (("pr", prs), ("issue", issues)):
        for obj in objs or []:
            if not isinstance(obj, dict):
                continue
            if kind == "pr":
                merged = parse_time(obj.get("mergedAt"))
                if merged is not None and merged < since:
                    continue
            it, gap = make_item(kind, obj)
            if it:
                items.append(it)
            else:
                missing.append(gap)

    merged_items = {}
    for it in items:
        k = item_key(it)
        if k in merged_items:
            merged_items[k]["refs"].append((it["kind"], it["number"], it["title"]))
        else:
            merged_items[k] = dict(it, refs=[(it["kind"], it["number"], it["title"])])

    date = current.strftime("%Y-%m-%d")
    out_dir = a.out or os.path.join(state_dir(), "checklists")
    out_file = os.path.join(out_dir, "checklist-%s.md" % date)

    counts = {}
    for h in history:
        if os.path.abspath(h.get("file", "")) == os.path.abspath(out_file):
            continue
        if h.get("date") == date:
            continue
        for k in set(h.get("items") or []):
            counts.setdefault(k, set()).add(h.get("date"))
    candidates = []
    for k, it in merged_items.items():
        seen = len(counts.get(k, set())) + 1
        if seen >= CANDIDATE_MIN:
            candidates.append((it, seen))

    lines = ["# Manual test checklist %s" % date, "",
             "Merged since %s. Mark each item [x] and fill `result: pass` or `result: fail <note>`," % iso(since),
             "then run `checklist.py record %s`." % os.path.basename(out_file), ""]

    def env_order(e):
        return (e == "unspecified environment", e.lower())

    by_env = {}
    for it in merged_items.values():
        by_env.setdefault(it["env"], []).append(it)
    if not by_env:
        lines += ["No merged PRs with test steps in this window.", ""]
    for env in sorted(by_env, key=env_order):
        lines.append("## %s" % env)
        lines.append("")
        group = sorted(by_env[env], key=lambda i: (i["platform"].lower(), i["screen"].lower(), str(i["number"])))
        platform = None
        for it in group:
            if it["platform"] and it["platform"] != platform:
                platform = it["platform"]
                lines += ["", "### %s" % platform, ""]
            who = "; ".join("%s %s" % (ref(k, n), t) for k, n, t in it["refs"])
            lines.append("- [ ] %s — %s: %s -> expected %s  result:" % (who, it["screen"], it["steps"], it["expected"]))
        lines.append("")

    lines += ["## No test steps", ""]
    if missing:
        for g in sorted(missing, key=lambda g: (g["kind"], str(g["number"]))):
            lines.append("- %s %s (%s)" % (ref(g["kind"], g["number"]), g["title"], g["why"]))
    else:
        lines.append("- none")
    lines += ["", "## Smoke", ""] + smoke_lines() + [""]

    if candidates:
        lines += ["## Candidate journey tests", "",
                  "Seen on %d or more checklists; worth an automated journey test." % CANDIDATE_MIN, ""]
        for it, seen in sorted(candidates, key=lambda c: (-c[1], c[0]["screen"].lower())):
            lines.append("- %s — %s: %s -> expected %s (on %d checklists)"
                         % (it["env"], it["screen"], it["steps"], it["expected"], seen))
        lines.append("")

    write_atomic(out_file, "\n".join(lines))

    entry = {"ts": iso(current), "date": date, "file": os.path.abspath(out_file),
             "since": iso(since), "items": sorted(merged_items)}
    kept = [h for h in history if os.path.abspath(h.get("file", "")) != entry["file"]]
    write_atomic(history_path(), "".join(json.dumps(h, sort_keys=True) + "\n" for h in kept + [entry]))

    print("wrote %s (%d items, %d without test steps, %d candidates)"
          % (out_file, len(merged_items), len(missing), len(candidates)))
    return 0


# ---------- record ----------

ITEM = re.compile(r"^\s*-\s+\[[xX]\]\s+(.*?)\s+result:\s*(pass|fail)\b[:\s-]*(.*)$", re.I)
CHECKED_NO_RESULT = re.compile(r"^\s*-\s+\[[xX]\]\s+(.*?)(?:\s+result:\s*)?$")
# Items start with refs, each followed by its title: "PR #1 Title; PR #4 Other — ...".
# Only a ref at the start or right after "; " counts, so "PR #40" inside a title does not.
LEAD_REF = re.compile(r"(?:^|;\s+)(PR|Issue) #(\d+)\b")


def cmd_record(a):
    try:
        lines = open(a.file, encoding="utf-8").read().splitlines()
    except OSError as e:
        raise Fail("cannot read %s: %s" % (a.file, e.strerror))
    name = os.path.basename(a.file)
    repo = ["--repo", a.repo] if a.repo else []
    section, sub = "", ""
    done = passed = failed = posted = 0
    for line in lines:
        h = HEADING.match(line)
        if h:
            if len(h.group(1)) <= 2:
                section, sub = h.group(2).strip(), ""
            else:
                sub = h.group(2).strip()
            continue
        if section.lower() in ("no test steps", "candidate journey tests"):
            continue
        m = ITEM.match(line)
        if not m:
            if CHECKED_NO_RESULT.match(line):
                print("skipped (checked, no pass/fail result): %s" % one_line(line), file=sys.stderr)
            continue
        text, result, note = m.group(1).strip(), m.group(2).lower(), m.group(3).strip()
        head = text.split(" — ", 1)[0]
        refs = LEAD_REF.findall(head) if section.lower() != "smoke" else []
        where = section + (" / " + sub if sub else "")
        body = "Manual test %s (%s, %s).\n\n%s" % (result.upper(), where, name, text)
        if note:
            body += "\n\nNote: %s" % note
        for kind, num in refs:
            args = ["pr" if kind == "PR" else "issue", "comment", num, "--body", body] + repo
            if a.dry_run:
                print("gh " + " ".join(shlex.quote(x) for x in args))
            else:
                try:
                    gh(args)
                except Fail as e:
                    raise Fail("%s (posted %d comments before this; rerun only the rest)" % (e, posted))
                posted += 1
                print("posted %s on %s #%s" % (result, kind, num))
        if result == "fail":
            failed += 1
            what = "; ".join("%s #%s" % r for r in refs) if refs else "smoke"
            detail = text.split(" — ", 1)[-1] if refs else text
            print("open bug: %s %s: %s" % (what, detail, note or "failed (no note)"))
        else:
            passed += 1
        done += 1
    print("%s %d results (%d pass, %d fail)" % ("would record" if a.dry_run else "recorded", done, passed, failed))
    return 0


def build_parser():
    p = argparse.ArgumentParser(prog="checklist.py", description="zStack manual-test checklist")
    sub = p.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("generate", help="write today's checklist")
    g.add_argument("--since")
    g.add_argument("--repo")
    g.add_argument("--from-json", dest="from_json")
    g.add_argument("--out")
    g.set_defaults(func=cmd_generate)
    r = sub.add_parser("record", help="post results from a filled checklist")
    r.add_argument("file")
    r.add_argument("--repo")
    r.add_argument("--dry-run", action="store_true")
    r.set_defaults(func=cmd_record)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except Fail as e:
        print("%s: %s" % (PROG, one_line(e)), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
    except Exception as e:  # last guard: one readable line, never a traceback
        print("%s: unexpected error: %s: %s" % (PROG, type(e).__name__, one_line(e)), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
