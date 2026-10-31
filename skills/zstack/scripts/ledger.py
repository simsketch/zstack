#!/usr/bin/env python3
"""ledger.py: the per-repo track record of merged zStack PRs.

  ledger.py add --pr <n> --sha <sha> --class <c> [--checks a,b]
  ledger.py flag --sha <sha> (--reverted | --bug <ref>)
  ledger.py stats [--json]
  ledger.py export <file>
  ledger.py import <file>          (dedupes by sha + event)
  ledger.py trust [--class <c>] [--gate <c>]   (what trust.sh runs)

File: $STATE/ledger.jsonl, one JSON object per line with `ts` and `event`
(merge | revert | bug). State dir: $ZSTACK_STATE_DIR, else
<git common dir>/zstack.

Suggested level (advice only): L2 when a class has >= 20 merges, a revert
rate <= 5% and a post-merge bug rate <= 5%; L1 otherwise; solo never above L1.

Effective level (trust): the configured `trust.<class>` from $STATE/config
(default L0 for solo, L1 for the rest), minus one when a revert in the class
is newer than `trust.<class>.since` (any revert when no since is set), floored
at L0, capped at L1 for solo, and capped at L2 unless zstack-fleet is
installed ($HOME/.agents/skills/zstack-fleet, $HOME/.claude/skills/zstack-fleet
or ZSTACK_FLEET=1).
"""
import argparse
import datetime as dt
import json
import os
import subprocess
import sys

PROG = "ledger"
CLASSES = ["docs", "tests", "small-ui", "feature", "solo"]
LEVELS = ["L0", "L1", "L2", "L3"]
MIN_MERGES = 20
MAX_RATE = 0.05


class Fail(Exception):
    """A one-line, user-facing error."""


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


def ledger_path():
    return os.path.join(state_dir(), "ledger.jsonl")


def now_iso():
    env = os.environ.get("ZSTACK_NOW")
    if env:
        return env
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_time(value):
    """Parse an ISO date or datetime; naive values are UTC. None when unparseable."""
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
    return t


def read_events(path):
    if not os.path.exists(path):
        return []
    events = []
    try:
        with open(path, encoding="utf-8") as fh:
            for num, line in enumerate(fh, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    raise Fail("%s:%d: not valid JSON" % (path, num))
                if not isinstance(obj, dict) or "event" not in obj:
                    raise Fail("%s:%d: missing event" % (path, num))
                events.append(obj)
    except OSError as e:
        raise Fail("cannot read %s: %s" % (path, e.strerror))
    return events


def append_events(path, events):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        with open(path, "a", encoding="utf-8") as fh:
            for ev in events:
                fh.write(json.dumps(ev, sort_keys=True) + "\n")
    except OSError as e:
        raise Fail("cannot write %s: %s" % (path, e.strerror))


def key(ev):
    return (ev.get("sha"), ev.get("event"))


def class_stats(events):
    merges = {}
    for ev in events:
        if ev.get("event") == "merge":
            merges.setdefault(ev.get("sha"), ev.get("class"))
    rows = {}
    for c in CLASSES:
        rows[c] = {"class": c, "merges": 0, "reverts": 0, "bugs": 0, "last_revert": None}
    for c in merges.values():
        rows.setdefault(c, {"class": c, "merges": 0, "reverts": 0, "bugs": 0, "last_revert": None})
        rows[c]["merges"] += 1
    reverted, bugged = set(), set()
    for ev in events:
        kind, sha = ev.get("event"), ev.get("sha")
        c = ev.get("class") or merges.get(sha)
        if c not in rows:
            continue
        if kind == "revert":
            if sha not in reverted:
                reverted.add(sha)
                rows[c]["reverts"] += 1
            t = parse_time(ev.get("ts"))
            last = parse_time(rows[c]["last_revert"])
            if t is not None and (last is None or t > last):
                rows[c]["last_revert"] = ev.get("ts")
        elif kind == "bug" and sha not in bugged:
            bugged.add(sha)
            rows[c]["bugs"] += 1
    for r in rows.values():
        m = r["merges"]
        r["revert_rate"] = (r["reverts"] / m) if m else 0.0
        r["bug_rate"] = (r["bugs"] / m) if m else 0.0
        r["suggested"] = suggest(r)
    return [rows[c] for c in CLASSES] + [rows[c] for c in sorted(rows) if c not in CLASSES]


def suggest(r):
    if r["class"] == "solo":
        return "L1"
    if r["merges"] >= MIN_MERGES and r["revert_rate"] <= MAX_RATE and r["bug_rate"] <= MAX_RATE:
        return "L2"
    return "L1"


def pct(rate):
    v = round(rate * 100, 1)
    return str(int(v)) if v == int(v) else str(v)


def read_config():
    path = os.path.join(state_dir(), "config")
    conf = {}
    if not os.path.exists(path):
        return conf
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                conf[k.strip()] = v.strip()
    except OSError as e:
        raise Fail("cannot read %s: %s" % (path, e.strerror))
    return conf


def fleet_installed():
    if os.environ.get("ZSTACK_FLEET") == "1":
        return True
    home = os.path.expanduser("~")
    return any(os.path.isdir(os.path.join(home, d, "skills", "zstack-fleet"))
               for d in (".agents", ".claude"))


def effective(row, conf, fleet):
    c = row["class"]
    configured = conf.get("trust.%s" % c) or ("L0" if c == "solo" else "L1")
    if configured not in LEVELS:
        raise Fail("config trust.%s=%s is not one of %s" % (c, configured, ", ".join(LEVELS)))
    level = LEVELS.index(configured)
    if row["reverts"]:
        last = parse_time(row["last_revert"])
        since = parse_time(conf.get("trust.%s.since" % c, ""))
        # An undated revert counts as newer than any since date.
        if since is None or last is None or last > since:
            level -= 1
    level = max(level, 0)
    if c == "solo":
        level = min(level, 1)
    if not fleet:
        level = min(level, 2)
    return configured, LEVELS[level]


def cmd_add(a):
    if a.cls not in CLASSES:
        raise Fail("unknown class '%s' (use %s)" % (a.cls, ", ".join(CLASSES)))
    path = ledger_path()
    events = read_events(path)
    if any(key(e) == (a.sha, "merge") for e in events):
        print("already recorded: merge %s" % a.sha)
        return 0
    checks = [c for c in (a.checks or "").split(",") if c]
    append_events(path, [{"ts": now_iso(), "event": "merge", "pr": a.pr, "sha": a.sha,
                          "class": a.cls, "checks": checks}])
    print("recorded merge of PR #%s (%s) as %s" % (a.pr, a.sha[:12], a.cls))
    return 0


def cmd_flag(a):
    path = ledger_path()
    events = read_events(path)
    merge = next((e for e in events if e.get("event") == "merge" and e.get("sha") == a.sha), None)
    if merge is None:
        matches = [e for e in events if e.get("event") == "merge"
                   and len(a.sha) >= 7 and str(e.get("sha", "")).startswith(a.sha)]
        if len(matches) == 1:
            merge = matches[0]
    if merge is None:
        raise Fail("no merge recorded for sha %s" % a.sha)
    ev = {"ts": now_iso(), "event": "revert" if a.reverted else "bug",
          "sha": merge["sha"], "pr": merge.get("pr"), "class": merge.get("class")}
    if a.bug:
        ev["ref"] = a.bug
    append_events(path, [ev])
    print("flagged %s: %s" % (merge["sha"][:12], ev["event"]))
    return 0


def cmd_stats(a):
    rows = class_stats(read_events(ledger_path()))
    if a.json:
        print(json.dumps(rows, indent=2, sort_keys=True))
        return 0
    print("%-9s %7s %8s %5s %9s" % ("class", "merges", "revert%", "bug%", "suggested"))
    for r in rows:
        print("%-9s %7d %8s %5s %9s" % (r["class"], r["merges"], pct(r["revert_rate"]),
                                         pct(r["bug_rate"]), r["suggested"]))
    return 0


def cmd_export(a):
    events = read_events(ledger_path())
    try:
        with open(a.file, "w", encoding="utf-8") as fh:
            for ev in events:
                fh.write(json.dumps(ev, sort_keys=True) + "\n")
    except OSError as e:
        raise Fail("cannot write %s: %s" % (a.file, e.strerror))
    print("exported %d events to %s" % (len(events), a.file))
    return 0


def cmd_import(a):
    if not os.path.isfile(a.file):
        raise Fail("import file not found: %s" % a.file)
    incoming = read_events(a.file)
    path = ledger_path()
    seen = {key(e) for e in read_events(path)}
    new = []
    for ev in incoming:
        if key(ev) not in seen:
            seen.add(key(ev))
            new.append(ev)
    append_events(path, new)
    print("imported %d events (%d already present)" % (len(new), len(incoming) - len(new)))
    return 0


def cmd_trust(a):
    for c in (a.cls, a.gate):
        if c and c not in CLASSES:
            raise Fail("unknown class '%s' (use %s)" % (c, ", ".join(CLASSES)))
    rows = class_stats(read_events(ledger_path()))
    conf, fleet = read_config(), fleet_installed()
    table = []
    for r in rows:
        configured, eff = effective(r, conf, fleet)
        table.append((r, configured, eff))
    if a.gate:
        r, configured, eff = next(t for t in table if t[0]["class"] == a.gate)
        ok = LEVELS.index(eff) >= 2
        print("%s: effective %s (%s)" % (a.gate, eff, "may merge on evidence" if ok else "below L2; the human merges"))
        return 0 if ok else 1
    print("%-9s %7s %8s %5s %10s %9s %9s" % ("class", "merges", "revert%", "bug%",
                                              "configured", "effective", "suggested"))
    for r, configured, eff in table:
        if a.cls and r["class"] != a.cls:
            continue
        print("%-9s %7d %8s %5s %10s %9s %9s" % (r["class"], r["merges"], pct(r["revert_rate"]),
                                                  pct(r["bug_rate"]), configured, eff, r["suggested"]))
    return 0


def build_parser():
    p = argparse.ArgumentParser(prog="ledger.py", description="zStack merge ledger")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("add", help="record a merged PR")
    s.add_argument("--pr", required=True)
    s.add_argument("--sha", required=True)
    s.add_argument("--class", dest="cls", required=True)
    s.add_argument("--checks", default="")
    s.set_defaults(func=cmd_add)
    s = sub.add_parser("flag", help="flag a merge as reverted or as causing a bug")
    s.add_argument("--sha", required=True)
    g = s.add_mutually_exclusive_group(required=True)
    g.add_argument("--reverted", action="store_true")
    g.add_argument("--bug", metavar="REF")
    s.set_defaults(func=cmd_flag)
    s = sub.add_parser("stats", help="per-class merges, revert and bug rates")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_stats)
    s = sub.add_parser("export", help="write the ledger to a file")
    s.add_argument("file")
    s.set_defaults(func=cmd_export)
    s = sub.add_parser("import", help="merge a ledger file in, deduped by sha + event")
    s.add_argument("file")
    s.set_defaults(func=cmd_import)
    s = sub.add_parser("trust", help="configured, effective and suggested levels")
    s.add_argument("--class", dest="cls")
    s.add_argument("--gate", metavar="CLASS")
    s.set_defaults(func=cmd_trust)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except Fail as e:
        print("%s: %s" % (PROG, e), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
