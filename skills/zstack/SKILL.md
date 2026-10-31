---
name: zstack
description: Routes a non-trivial engineering goal to a playbook, an execution shape and a set of cited principles. Use for bugs and bug tickets (cause known or unknown), explaining how a system works or why it is built that way across files, choosing between approaches ("which approach should we take?"), new features, refactors, performance work, code or PR review, opening and landing PRs, "what should I test today", running work in parallel or overnight, "is it live" or "did it ship", taking over another agent's work, pausing cleanly, or when the human says they are busy testing. Answers to /zstack. Skip for one-line questions and trivial edits.
license: MIT
metadata:
  version: "1.0.0"
  source: "https://github.com/<owner>/zstack"
---

# zStack

A goal goes in. A playbook, an execution shape and a short list of principles come out, and every
decision you make afterwards names the principle behind it.

`<zstack dir>` is the folder that holds this SKILL.md. Every `scripts/` and `templates/` path in this
skill, its playbooks and its briefs is relative to it, and a subagent brief passes the absolute
`<zstack dir>` (the `{{ZSTACK_DIR}}` slot in the worker-brief template).

The repo's own rules (CLAUDE.md, AGENTS.md, CONTRIBUTING and the like) outrank this skill. When they
conflict, follow the repo and say which rule won.

## When it applies

Use zStack when the work has more than one reasonable path, touches more than one file, or ends in a
claim someone will rely on ("fixed", "shipped", "safe to merge"). Typical inputs:

- a bug whose cause is unknown, or a bug ticket
- a feature, refactor, performance problem or prototype question
- a review of a PR, branch or diff, or a PR to open, babysit or land
- a queue of tickets to run while the human is away
- "is it live?", "what should I test?", "pick this up", "stop here for today"

Skip it for one-line questions, a lookup, or a trivial edit the human has fully specified (rename this,
fix this typo). Answer those directly.

## On activation

Work through these seven steps in order, every time.

1. **Restate the goal and the definition of done** in one or two lines. If done is unclear and the work
   is anything other than an investigation, ask one question. In human-busy mode, write the question to
   the decision page, record a default and flag it `revisit`.
2. **Pick a playbook** from the catalog below. Overrides come before narrow matches: work the human wants
   to walk away from, or that spans days, goes to `autopilot-queue` (or a fleet wave when zstack-fleet is
   installed); "which approach is better?" goes to `prototype`. When nothing fits, write a one-off
   playbook in the same shape as the shipped ones and save it under `.git/zstack/playbooks/<name>.md` so
   the next session can reuse it.
3. **Pick an execution shape** from the signals in the next section.
4. **State the route in one line**, in exactly this format:

   ```
   Route: <playbook>[ -> <chained playbook>], shape: <inline|one subagent|lane|fleet wave>, principles: <p1>, <p2>[, ...]
   ```

   Example: `Route: debug -> bug-class-sweep, shape: one subagent, principles: reproduce-first, fix-the-class, evidence-before-the-word`

5. **Copy the playbook's steps into your todo list word for word.** A step you skip stays in the list,
   marked skipped, with the reason.
6. **Read each principle leaf before applying it** (`references/principles/<name>.md`). You may cite
   only principles whose leaf you read in this session. Every final reply and PR body names the
   principles that shaped a decision and what each one changed.
7. **Propagate down.** Every subagent brief starts with "Read the zstack router first", then the chosen
   playbook, then the principles in force (see "Briefing subagents" below).

## Execution shapes

| Shape | What it is | Pick when |
|---|---|---|
| inline | this session does the work itself | one area, small, done is clear, or the harness cannot run subagents |
| one subagent | one background worker in its own worktree; this session coordinates | one area, but long enough to crowd your context, or the human wants to keep talking |
| lane | 2-6 workers in parallel worktrees, one coordinator, merges one at a time | several pieces that each merge and revert on their own, with predicted files disjoint |
| fleet wave | many lanes across repos or accounts with lane leads, a merge desk and a safety net | zstack-fleet installed, its accounts check green, quota under pace, merge mode Normal |

Read every signal, in order. Each one can only shrink the shape, never grow it, and the smallest shape
left after all six is the one you run.

1. **Definition-of-done clarity.** While done is unclear, stay at inline or one subagent.
2. **Predicted file overlap.** Pieces that are likely to edit the same files join one lane or run in
   sequence.
3. **Solo classes.** Migrations, auth and security, infra and CI workflows, and payments each run as
   their own lane, never batched with other work, and their PRs open with a `hold` label.
4. **Harness capability.** Look up what this harness can do in `references/harness-capabilities.md`.
   With no background subagents, lanes run in sequence, or as headless runs where the harness has a
   headless mode.
5. **Fleet signals** (only with zstack-fleet installed): merge mode, quota pace, CI budget headroom and
   drift of the open queue. A Slow or Drain merge mode caps new work and points workers at open PRs.
6. **The human's state.** In human-busy mode, prefer shapes that need no answer soon.

**Starting a lane.** Start workers a few at a time, at most three in any two minutes, and wait for
each batch to report before starting the next. A slow start spreads the load on the machine and the
repo, and a bad brief shows up after three workers instead of six.

When you choose a smaller shape than the work wanted, name the signal that capped it in one line, for
example: "wanted a lane;
this harness has no background subagents, so the three pieces run in sequence."

**Fleet hand-off.** With zstack-fleet installed, read its SKILL.md before choosing fleet wave; without it
cap at lane and say so.

## Playbook catalog

Each playbook lives at `playbooks/<name>.md` and has the same shape: use when, inputs, numbered steps,
the gate that ends it, the principles it cites, and the shape it prefers.

| Playbook | Use when | Ends with |
|---|---|---|
| `investigate` | a read-only question: how something works, why it exists | an answer with file and line citations and no code change |
| `debug` | a bug whose cause is unknown | a reproduced, root-caused, tested fix, then chains to `bug-class-sweep` |
| `bug-class-sweep` | a bug's cause is known, or a bug ticket arrives | every instance classified and fixed or ticketed, a guardrail, and a note on why tests missed it |
| `perf` | slowness someone measured or can measure | before and after numbers taken on the same baseline |
| `feature` | new behavior | data shape and owner named first, tests first where the repo has tests |
| `refactor` | a structure change that must keep behavior | proof behavior held: passing tests or a recorded diff of outputs |
| `prototype` | "which approach?" | a throwaway comparison that settles the choice, and the decision written down |
| `review` | review a PR, branch or diff | a verdict of PASS, CHANGES NEEDED or FIX FIRST with findings by severity |
| `babysit-pr` | drive an open PR to merge-ready | conflicts resolved, threads answered, checks recorded at the head commit |
| `land` | open or land a PR | small ordered commits, the evidence packet in the body, merge pinned to the verified head |
| `autopilot-queue` | a queue of independent tickets to run to merged, often unattended | one owner per ticket, a second agent verifying, merges within the trust ladder |
| `verify-release` | "is it live?", "did it ship?", "is it deployed?" | implemented, deployed and verified stated separately with machine evidence |
| `manual-test-checklist` | "what should I test today?", or the end of a merge batch | an ordered checklist per environment, with results written back to the PRs |
| `pickup` | take over another agent's or person's in-flight work | state read from disk and the handoff file, the plan restated before any edit |
| `pause` | stop cleanly for now | a handoff file and a WIP commit, with nothing left only in a working tree |
| `human-busy` | the human says they are busy, or two questions sit unanswered for 30 minutes | one decision page, safe defaults flagged `revisit`, work continuing on what needs no answer |

Chains: `debug` always continues into `bug-class-sweep` once the cause is known. Work that ends in a PR
continues into `land`. A failed item on a manual-test checklist opens a bug, which starts `debug` or
`bug-class-sweep`.

## Principle index

Each principle has a leaf at `references/principles/<name>.md` with the rule, why it exists, and the
checks that show you followed it. Read the leaf before you cite it.

**Method**

- `reproduce-first`: when fixing a bug. No fix lands before a reproduction, or a written reason why one
  is impossible.
- `fix-the-class`: when a cause is known. Search for every sibling of the bug before calling it fixed.
- `smallest-reversible-change`: when shaping commits and PRs. One ticket per change, and each commit
  can be reverted alone.
- `data-shape-first`: when starting a feature. Name the data, its shape and its owner before any UI or
  endpoint.
- `subtract-first`: when about to add code, config or a dependency. Try removing or reusing first.

**Evidence**

- `evidence-before-the-word`: when about to say shipped, live, fixed or passing. Each word needs machine
  evidence at a named commit.
- `three-words`: when reporting status. Implemented, deployed and verified are reported separately.
- `empty-check-fails`: when reading a check result. A check that ran zero tests failed.
- `numbers-from-tested-queries`: when giving a human a number. It comes from a named, tested query, or
  it is marked unverified.

**Parallel work**

- `one-owner-per-file`: when splitting work across workers. Each hot file is leased to one lane.
- `rebase-once-late`: when branches fall behind. Rebase at merge time, oldest PR first, once.
- `count-the-living`: when counting workers. A worker counts only if it produced output in the last 10
  minutes.

**Safety**

- `report-the-guard`: when a hook, guard, limit or permission blocks you. Report it and stop; never
  route around it.
- `secrets-stay-in-process`: when work touches credentials. Never read or print a credential file.
- `stop-by-pid`: when stopping a process. Stop it by a pid you captured or a path in your own worktree.

**Human**

- `ask-with-options`: when a decision is needed. Product, scope, money, data deletion, security,
  production and disputes go to the human with options and a recommendation; answer everything else
  from code, docs or prior words, and cite the source.
- `leave-it-better-separately`: when you notice an unrelated defect. Fix it in its own tagged commit if
  it passes the drive-by test; otherwise ticket it.
- `spend-attention-carefully`: when you have questions. Batch them, and keep working on whatever does
  not depend on the answers.

**Meta**

- `name-what-changed`: in every final reply and PR body. Name the principles that shaped the work and
  what each one changed.

## Evidence and gates

Three words, kept apart in every report (details in `references/evidence.md`):

- **implemented**: merged, with the merge sha
- **deployed**: running in a named environment, proven by the serving artifact containing the commit
- **verified**: someone checked the behavior there, with who and when

Never write "shipped" or "live" without the deployed evidence.

Four gates before a merge:

1. A check counts only when recorded on a clean tree at the PR head commit:
   `<zstack dir>/scripts/zcheck.sh --name <n> -- <cmd>`, confirmed with `<zstack dir>/scripts/zcheck.sh --verify <sha> <name>...`.
   Zero tests fails.
2. The merge is pinned to the verified head (`gh pr merge --match-head-commit <sha>`).
3. One merge at a time per repo.
4. Sensitive classes open with `hold`; a push after review needs a delta review before the hold comes
   off.

A PR's class comes from `<zstack dir>/scripts/classify.sh` (riskiest file wins, unmatched files count as `feature`).
You may raise a class by hand and never lower it. How much you may do alone is set per class by the
trust ladder: L0 propose, L1 open, L2 merge on evidence, L3 batch (fleet only). Check it with
`<zstack dir>/scripts/trust.sh --gate <class>`, and record each merge with `<zstack dir>/scripts/ledger.py add`. Only the human
raises a level. The full ladder and class rules are in `references/evidence.md`; every state file is
listed in `references/state.md`.

## Drive-by fixes

An unrelated defect you notice may ride in the same PR only when all of these hold: one file (or one
file plus its test), it has a test or is a pure typo, dead import or comment fix, the file is outside
solo classes and nobody else's lease, and it is under about 20 changed lines. It goes in its own commit
with the subject prefix `drive-by:` and a line under `## Drive-bys` in the PR body. Anything larger
becomes a ticket listed under `## Follow-ups` with its evidence. Full rule: `references/drive-by.md`.

## Human-busy mode

Enter the `human-busy` playbook when the human says they are occupied ("I'm testing for the next two
hours", "in meetings until 3"), or on your own after two questions have gone unanswered for 30 minutes.
Questions then go to one decision page (`.git/zstack/decisions.md`, from `<zstack dir>/templates/decision-page.md`),
the human gets one short message when the page changes, and work continues on whatever needs no answer.
Safe, reversible defaults proceed flagged `revisit`; anything on the `ask-with-options` list waits.

## Briefing subagents

Every brief you hand a subagent, worker or headless run starts with these lines, in this order (the
full brief shape is `<zstack dir>/templates/worker-brief.md`):

1. "Read the zstack router first" and where it lives.
2. The playbook it is running, and the route line.
3. The principles in force, by name.
4. The drive-by rule, no CI polling loops, no credential reads, and "report any guard that blocks you".

A worker that receives a brief without these lines asks for them before starting; a headless run that
cannot ask stops and reports the missing lines.

## Scripts and templates

Scripts (bash 3.2 and Python 3 standard library, state under `.git/zstack/`):

- `<zstack dir>/scripts/zcheck.sh`: record a check at the head commit, `--verify` before merge, `--list` to see them
- `<zstack dir>/scripts/classify.sh`: compute a PR's class from its files (`--pr <n>`, `--base <ref>`, `--files <file>`)
- `<zstack dir>/scripts/ledger.py`: record merges, reverts and bugs; `stats`, `export`, `import`
- `<zstack dir>/scripts/trust.sh`: per-class track record and effective trust level; `--gate <class>`
- `<zstack dir>/scripts/checklist.py`: `generate` the manual-test checklist and `record` results back to PRs

Templates: `<zstack dir>/templates/pr-body.md`, `decision-page.md`, `sweep-report.md`, `handoff.md`,
`worker-brief.md`, `classes.conf`, `config`, `smoke.md`.

## Closing every task

End with a reply that carries the route line, what was done, the three evidence words where they apply,
and one line per cited principle saying what it changed. If you followed a repo rule over this skill,
name it.
