#!/usr/bin/env bash
# run-trigger-tests.sh <claude|codex> [outdir]
#
# Runs each prompt in trigger-prompts.txt once, headless, against a fresh copy
# of the acme-notes demo repo (setup-demo.sh) with this zstack skill linked at
# project level:
#   claude: <demo>/.claude/skills/zstack -> this repo's skills/zstack
#   codex:  <demo>/.agents/skills/zstack -> this repo's skills/zstack
# Nothing is installed in ~/.claude/skills or ~/.agents/skills.
#
# Every prompt gets the suffix
#   "Dry run: give the route line and your todo list, then stop before editing any files."
# and runs read-only (claude: plan permission mode, no edit tools; codex:
# read-only sandbox), with stdin closed and a timeout.
#
# Output: <outdir>/NN.txt per prompt (default outdir: results/<harness>/ next
# to this script). Each file starts with a header (prompt, exit code, seconds,
# which zstack files the agent read) and then the agent's final message. Temp
# paths are written as <tmp> and the home directory as ~.
# Raw event logs stay outside the repo, in a temp dir printed at the end.
#
# Environment:
#   ZSTACK_TRIGGER_TIMEOUT   seconds per prompt (default 600)
#   ZSTACK_TRIGGER_JOBS      prompts run at once (default 5)
#   ZSTACK_TRIGGER_ONLY      space-separated prompt numbers to run, e.g. "2 7"
#   ZSTACK_CLAUDE / ZSTACK_CODEX   binaries to run (default claude / codex)
set -u

here="$(cd "$(dirname "$0")" && pwd -P)"
skill_dir="$(cd "$here/.." && pwd -P)"
harness="${1:-}"
case "$harness" in
  claude|codex) ;;
  *) echo "usage: run-trigger-tests.sh <claude|codex> [outdir]" >&2; exit 2 ;;
esac
outdir="${2:-$here/results/$harness}"
mkdir -p "$outdir"
outdir="$(cd "$outdir" && pwd -P)"
prompts="$here/trigger-prompts.txt"
limit="${ZSTACK_TRIGGER_TIMEOUT:-600}"
jobs_max="${ZSTACK_TRIGGER_JOBS:-5}"
only="${ZSTACK_TRIGGER_ONLY:-}"
suffix="Dry run: give the route line and your todo list, then stop before editing any files."
raw_root="$(mktemp -d "${TMPDIR:-/tmp}/zstack-trigger.XXXXXX")"
raw_root="$(cd "$raw_root" && pwd -P)"

bin_claude="${ZSTACK_CLAUDE:-claude}"
bin_codex="${ZSTACK_CODEX:-codex}"
if [ "$harness" = claude ]; then bin="$bin_claude"; else bin="$bin_codex"; fi
command -v "$bin" >/dev/null 2>&1 || { echo "run-trigger-tests.sh: $bin not found on PATH" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "run-trigger-tests.sh: python3 is required" >&2; exit 1; }

# with_timeout <seconds> <cmd...>
with_timeout() {
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$s" "$@"
  else
    perl -e 'my $s = shift; $SIG{ALRM} = sub { kill "TERM", -$pid; exit 124 };
             $pid = fork(); if ($pid == 0) { setpgrp(0, 0); exec @ARGV or exit 127 }
             alarm $s; waitpid($pid, 0); exit($? >> 8)' "$s" "$@"
  fi
}

# run_one <NN> <prompt>
run_one() {
  local nn="$1" prompt="$2" raw="$raw_root/$1" work rc start secs full
  mkdir -p "$raw"
  work="$raw/acme-notes"
  bash "$here/setup-demo.sh" "$work" > "$raw/setup.log" 2>&1 || {
    printf 'setup-demo.sh failed, see raw log\n' > "$outdir/$nn.txt"; return 0; }
  if [ "$harness" = claude ]; then
    mkdir -p "$work/.claude/skills"
    ln -s "$skill_dir" "$work/.claude/skills/zstack"
  else
    mkdir -p "$work/.agents/skills"
    ln -s "$skill_dir" "$work/.agents/skills/zstack"
  fi
  # Keep the links out of `git status` so the repo looks clean to the agent.
  printf '.claude/\n.agents/\n' >> "$work/.git/info/exclude"
  full="$prompt

$suffix"
  start=$(date +%s)
  if [ "$harness" = claude ]; then
    (cd "$work" && with_timeout "$limit" "$bin_claude" -p "$full" \
        --permission-mode plan \
        --disallowedTools "Edit Write NotebookEdit Agent" \
        --output-format stream-json --verbose \
        < /dev/null > "$raw/events.jsonl" 2> "$raw/stderr.log")
    rc=$?
  else
    (cd "$work" && with_timeout "$limit" "$bin_codex" exec --skip-git-repo-check \
        -s read-only -C "$work" --json -o "$raw/last.txt" "$full" \
        < /dev/null > "$raw/events.jsonl" 2> "$raw/stderr.log")
    rc=$?
  fi
  secs=$(( $(date +%s) - start ))
  python3 -I - "$harness" "$raw" "$work" "$HOME" "$prompt" "$rc" "$secs" > "$outdir/$nn.txt" <<'PY'
import json, os, re, sys
harness, raw, work, home, prompt, rc, secs = sys.argv[1:8]
events = []
try:
    for line in open(os.path.join(raw, "events.jsonl"), encoding="utf-8", errors="replace"):
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except ValueError:
                pass
except OSError:
    pass

def walk(o):
    if isinstance(o, dict):
        yield o
        for v in o.values():
            yield from walk(v)
    elif isinstance(o, list):
        for v in o:
            yield from walk(v)

skill_calls, files, final = [], [], ""
pat = re.compile(r"(?:skills/zstack/|\$\w+/|\$\{\w+\}/)?((?:SKILL\.md)|(?:playbooks|references|templates)/[A-Za-z0-9_./${}-]+)")
for ev in events:
    for d in walk(ev):
        if d.get("type") == "tool_use":
            inp = d.get("input") or {}
            if d.get("name") == "Skill":
                skill_calls.append(str(inp.get("skill") or inp.get("command") or inp))
                if "zstack" in skill_calls[-1]:
                    files.append("SKILL.md")
            for v in inp.values():
                if isinstance(v, str):
                    files += pat.findall(v)
        cmd = d.get("command")
        if isinstance(cmd, str):
            files += pat.findall(cmd)
        if isinstance(cmd, list):
            files += pat.findall(" ".join(map(str, cmd)))
    if harness == "claude" and ev.get("type") == "result":
        final = ev.get("result") or ""
if harness == "codex":
    try:
        final = open(os.path.join(raw, "last.txt"), encoding="utf-8").read()
    except OSError:
        final = ""
seen = []
for f in files:
    if f not in seen:
        seen.append(f)
err = ""
if not final.strip():
    try:
        err = open(os.path.join(raw, "stderr.log"), encoding="utf-8", errors="replace").read()[-2000:]
    except OSError:
        pass

def redact(s):
    for p in (os.path.realpath(raw), raw, os.path.realpath(work), work):
        s = s.replace(p, "<tmp>")
    s = re.sub(r"/(private/)?(var/folders|tmp)/[^\s'\"`)]*", "<tmp>", s)
    return s.replace(home, "~")

print("harness: %s" % harness)
print("prompt: %s" % prompt)
print("exit: %s  seconds: %s%s" % (rc, secs, "  (timed out)" if rc == "124" else ""))
if harness == "claude":
    print("skill tool calls: %s" % (", ".join(skill_calls) or "none"))
print("zstack files read: %s" % (", ".join(seen) or "none"))
print("---")
print(redact(final).rstrip())
if err:
    print("--- stderr (tail)")
    print(redact(err).rstrip())
PY
  echo "done $nn ($harness, exit $rc, ${secs}s)"
}

n=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  n=$((n + 1))
  nn="$(printf '%02d' "$n")"
  if [ -n "$only" ]; then
    case " $only " in *" $n "*|*" $nn "*) ;; *) continue ;; esac
  fi
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$jobs_max" ]; do
    sleep 2
  done
  run_one "$nn" "$line" &
done < "$prompts"
wait

echo "results: $outdir"
echo "raw logs (not in the repo): $raw_root"
