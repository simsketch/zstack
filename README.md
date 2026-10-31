# zStack

zStack (spoken "Zee Stack") is an agent skill for day-to-day engineering work. You give it a goal. It picks a playbook (how
to do the work) and an execution shape (how wide to run it), copies the playbook's steps into the agent's
todo list, and makes the agent name the working principles behind each decision and what each one
changed. The output is meant to be reviewable at volume: every PR carries an evidence packet you can
close from.

One skills tree serves Claude Code, Codex, Cursor, Gemini CLI, OpenCode and Pi. It follows the
[Agent Skills](https://agentskills.io) format and ships a routing hint for [AGENTS.md](https://agents.md).
MIT licensed. zStack is unrelated to the 500x `ship-stack` skill, which scaffolds a SaaS starter.

## How routing works

On a non-trivial goal (or `/zstack <goal>`), the agent:

1. restates the goal and what done means;
2. picks a playbook from the catalog;
3. picks an execution shape from a fixed list of signals;
4. states the route in one line;
5. copies the playbook's steps into its todo list word for word, keeping skipped steps with a reason;
6. reads each principle's leaf file before citing it;
7. starts every subagent brief with "Read the zstack router first", the playbook and the principles.

A route line looks like this:

```
Route: debug -> bug-class-sweep, shape: inline, principles: reproduce-first, fix-the-class, evidence-before-the-word
```

The repo's own rules (CLAUDE.md, AGENTS.md, CONTRIBUTING) outrank the skill. When they conflict, the
agent follows the repo and says which rule won. One-line questions and fully specified trivial edits
skip zStack.

## Playbooks

Sixteen playbooks, each in `skills/zstack/playbooks/` with the same parts: use when, inputs, numbered
steps, the gate that ends it, the principles it cites and the shape it prefers.

| Playbook | Use when |
|---|---|
| `investigate` | a read-only question: how something works, why it exists |
| `debug` | a bug whose cause is unknown; chains into `bug-class-sweep` |
| `bug-class-sweep` | a bug's cause is known, or a bug ticket arrives |
| `perf` | slowness someone measured or can measure |
| `feature` | new behavior |
| `refactor` | a structure change that must keep behavior |
| `prototype` | "which approach?" |
| `review` | review a PR, branch or diff |
| `babysit-pr` | drive an open PR to merge-ready |
| `land` | open or land a PR |
| `autopilot-queue` | a queue of independent tickets to run to merged, often unattended |
| `verify-release` | "is it live?", "did it ship?" |
| `manual-test-checklist` | "what should I test today?" |
| `pickup` | take over another agent's or person's in-flight work |
| `pause` | stop cleanly for now |
| `human-busy` | the human is busy testing or in meetings |

When nothing fits, the agent writes a one-off playbook in the same shape and saves it under
`.git/zstack/playbooks/` for the next session.

## Principles

Nineteen principles, each a short leaf in `skills/zstack/references/principles/` with the rule, why it
exists and the checks that show it was followed.

- **Method:** `reproduce-first`, `fix-the-class`, `smallest-reversible-change`, `data-shape-first`,
  `subtract-first`
- **Evidence:** `evidence-before-the-word`, `three-words`, `empty-check-fails`,
  `numbers-from-tested-queries`
- **Parallel work:** `one-owner-per-file`, `rebase-once-late`, `count-the-living`
- **Safety:** `report-the-guard`, `secrets-stay-in-process`, `stop-by-pid`
- **Human:** `ask-with-options`, `leave-it-better-separately`, `spend-attention-carefully`
- **Meta:** `name-what-changed`

## Execution shapes

| Shape | What it is |
|---|---|
| inline | the current session does the work |
| one subagent | one background worker in its own worktree; the session coordinates |
| lane | 2-6 workers in parallel worktrees, one coordinator, merges one at a time |
| fleet wave | many lanes across repos or accounts (needs the zstack-fleet add-on) |

Six signals pick the shape, and each can only shrink it: how clear done is, predicted file overlap,
solo classes (migrations, auth, infra, payments run alone), what the harness can do, fleet signals, and
whether the human is busy. When a signal caps the shape, the agent says which one. Lanes start a few
workers at a time, at most three in any two minutes.

## Evidence packet and the three words

Every PR body (template: `skills/zstack/templates/pr-body.md`) carries the route, the principles and
what each changed, the PR class, the checks recorded at the head commit, a "How to test" block,
drive-bys and follow-ups. Status is reported with three separate words:

- **implemented:** merged, with the merge sha
- **deployed:** running in a named environment, proven by the serving artifact containing the commit
- **verified:** someone checked the behavior there, with who and when

"Shipped" and "live" are only written with the deployed proof in hand. Before a merge, four gates
apply: checks recorded on a clean tree at the head commit (a check that ran zero tests fails), the
merge pinned to the verified head, one merge at a time per repo, and a `hold` label on sensitive
classes.

## Bug-class sweeps

A fixed bug chains into a sweep by default. The agent names the class in one line, writes it as a
searchable pattern, runs it across the repo (and any sibling repos you list), classifies every hit as
confirmed, suspect or safe, fixes or tickets each one, adds a guardrail that fails on the pattern, and
writes a short note on why tests missed it. A true one-off gets a one-line `no class:` note instead.

## Drive-by fixes

An unrelated defect may ride in the same PR when it is one file (or one file and its test), has a test
or is a pure typo, dead import or comment fix, sits outside solo classes and other workers' leases, and
is under about 20 changed lines. It goes in its own commit prefixed `drive-by:` and is listed under
`## Drive-bys`. Anything larger becomes a follow-up with its evidence.

## Human-busy mode

Say "I'm testing for the next two hours" (or leave two questions unanswered for 30 minutes) and the
agent moves its questions to one decision page at `.git/zstack/decisions.md`, sends you one short
message when the page changes, and keeps working on whatever needs no answer. Safe, reversible defaults
go ahead flagged `revisit`; product, scope, money, data deletion, security and production questions
wait for you.

## Manual-test checklist

"What should I test today?" runs `checklist.py generate`, which reads the "How to test" blocks of
recently merged PRs and writes an ordered checklist per environment, with your fixed smoke list
appended. You mark results in the file; `checklist.py record` posts them back to the PRs, and each
failure opens a bug that starts a sweep. Journeys that keep showing up are suggested as candidates for
automated tests.

## Trust ladder

Per repo and per PR class (`docs`, `tests`, `small-ui`, `feature`, `solo`), a level sets how much the
agent may do alone:

| Level | The agent may |
|---|---|
| L0 draft only | open only a draft PR labelled `hold`; never mark it ready, remove `hold` or merge; you take it over |
| L1 open | open ready PRs with the evidence packet; you merge |
| L2 merge on evidence | merge its own PRs that pass all four gates, one at a time |
| L3 batch | assemble and merge batches (zstack-fleet only) |

Only you raise a level, in `.git/zstack/config`. A revert in a class drops it one level until you
restore it. Solo classes start at L0 and stay at L1 or below. `trust.sh` shows each class's track record from the
merge ledger and suggests a level; the suggestion is advice.

## Install

Restart your agent session after installing.

**Any harness, from a clone:**

```
git clone https://github.com/<owner>/zstack.git
./zstack/install.sh
```

`install.sh` symlinks `skills/zstack` into `~/.agents/skills/` and `~/.claude/skills/`, so a `git pull`
updates every harness, then runs the Agent Skills validator when one is available. It refuses to
replace a real folder of the same name. `./install.sh --uninstall` removes only its own links.

**Claude Code:** in one step (Claude Code 2.1.275 or later):

```
/plugin install zstack --marketplace <owner>/zstack
```

or in two: `/plugin marketplace add <owner>/zstack`, then `/plugin install zstack@zstack`. From a shell,
`claude plugin install zstack --marketplace <owner>/zstack` does the same. A plugin skill is namespaced,
so on this route invoke it with `/zstack:zstack <goal>` (or state the goal); with the installer it is
`/zstack <goal>`.

**Codex CLI:** `codex plugin marketplace add <owner>/zstack`, then `codex plugin add zstack@zstack`, or
use the installer. The plugin skill is listed as `zstack:zstack`; state the goal or mention the skill.

**Cursor:** load the repo's root `plugin.json`, or rely on the `~/.agents/skills/` symlink.

**Gemini CLI:** `gemini extensions install https://github.com/<owner>/zstack`, or use the symlink, then
`/skills reload`.

**OpenCode:** the `~/.agents/skills/` symlink from the installer; no plugin needed.

**Pi:** `pi install git:https://github.com/<owner>/zstack`, or use the symlink.

The Claude Code and Codex plugin installs also add a session-start hook that prints a two-line routing
hint; it reads no files and takes no action. The Claude Code hook was seen running on a clean profile.
The Codex hook is not live-tested: Codex asks you to review and trust a plugin's hooks before they run,
and the hook command exits quietly when Codex gives it no plugin root. The Gemini CLI extension loads
the same hint from `GEMINI.md`. Install commands and their recorded output are in
`skills/zstack/example/results/plugin-install.md`.

## Optional repo setup

None of this is required; each piece makes zStack more useful in a repo you work in often.

- **Routing hint:** paste `AGENTS.md.snippet` into the repo's AGENTS.md (or CLAUDE.md, or import
  `@AGENTS.md` from CLAUDE.md).
- **PR template:** copy `skills/zstack/templates/pr-body.md` to `.github/pull_request_template.md`.
- **Smoke list:** copy `skills/zstack/templates/smoke.md` to `.git/zstack/smoke.md` and edit it.
- **Trust and config:** copy `skills/zstack/templates/config` to `.git/zstack/config` (trust levels,
  sibling repos to sweep, a notify command, the base branch). Its `notify_cmd` is per repo; with
  zstack-fleet installed, an empty one falls back to fleet's machine-wide `~/.config/zstack/config`.
- **Labels:** `gh pr create --label` refuses a label the repo lacks, so create the two zStack uses once:
  `gh label create hold` and `gh label create manual-verify`.
- **PR classes:** `skills/zstack/scripts/classify.sh --init` writes `.git/zstack/classes.conf` with
  safe defaults you can extend.

## Example prompts

- "zstack: users report the CSV export drops the last row"
- "The CSV export is dropping rows for some users and I don't know why. Fix it."
- "zstack: review PR 214"
- "Add a tags field to notes: stored, exported and filterable from the CLI."
- "What should I test today?"
- "I'm testing for two hours, keep going."
- "Is the CSV export fix live in production yet?"
- "These three tickets are independent, run them in parallel."
- "Take over the half-finished work on branch wip/search."
- "How much can I trust you on docs PRs here?"

## Scripts

All in `skills/zstack/scripts/`: bash 3.2 and the Python 3 standard library, plus git and `gh`. State
goes under `.git/zstack/`.

| Script | What it does |
|---|---|
| `zcheck.sh` | record a check at the head commit (`--name <n> -- <cmd>`), `--verify <sha> <names>` before merge, `--list` |
| `classify.sh` | compute a PR's class from its files (`--pr`, `--base`, `--files`); `--init` writes `classes.conf` |
| `ledger.py` | `add` a merge, `flag` it reverted or as a bug's cause; `stats`, `export`, `import` |
| `trust.sh` | per-class track record and effective trust level; `--gate <class>` before a merge |
| `checklist.py` | `generate` the manual-test checklist and `record` results back to PRs |

Repo-level: `scripts/check-manifests.sh` (every manifest agrees with the skills tree, the playbook
catalog matches the files, the Agent Skills validator passes) and `scripts/prepublish-grep.sh` (fails
on secrets, absolute home paths, private emails and terms from a list kept outside the tree).

## State

Per repo, everything lives in `.git/zstack/` (the git common dir), so every worktree sees the same
files and none of them shows in `git status`: config, PR class rules, recorded checks, the merge
ledger, sweep reports, the decision page, checklists, handoffs, one-off playbooks, and `board.md`,
where a worker whose approach failed leaves a one-line `FAIL` entry so others skip that dead end.
Nothing there holds secrets and nothing is pushed. While it runs, core zStack writes nothing outside
the repo; `install.sh` adds only its symlinks under `~/.agents/skills/` and `~/.claude/skills/`. The full
list is in `skills/zstack/references/state.md`.

## Harnesses

| Harness | Status |
|---|---|
| Claude Code | tested |
| Codex CLI | tested |
| Cursor | documented, best effort |
| Gemini CLI | documented, best effort |
| OpenCode | documented, best effort |
| Pi | documented, best effort |

The skill text uses capability words ("spawn a background subagent in its own worktree", "ask the
user"). `skills/zstack/references/harness-capabilities.md` maps them to each harness's tools and gives
a fallback when a harness lacks one, for example running pieces in sequence when there are no
background subagents.

## Try it on the demo repo

`skills/zstack/example/setup-demo.sh <dir>` builds `acme-notes`, a small fictional Python notes CLI
with a CSV export that drops the last row, a sibling off-by-one in `list --limit`, a README typo, a
`feature/tags` branch to review and a half-done `wip/search` branch with a handoff file.

`skills/zstack/example/run-trigger-tests.sh <claude|codex>` runs the ten prompts in
`trigger-prompts.txt` headless against fresh copies of that repo, with the skill linked at project
level only, and saves each answer under `example/results/`. `example/results/SUMMARY.md` records the
latest run: whether the skill fired, the route line, and whether the todo list matched the playbook.

## Limits

- Review speed still sets how much parallel work is worth running. zStack makes each PR quicker to
  review, and a person still has to review it.
- The trust ladder is advice computed from your own merge history. It cannot know about risk your
  history does not show.
- Routing is done by the model reading the skill. It is usually right, and the route line makes it
  easy to correct when it is not.
- Harnesses other than Claude Code and Codex are documented from their docs and may need small fixes.
- zStack never runs CI pollers, reads credential files, switches GitHub accounts or changes a guard at
  runtime. Work that needs those stays with you.

## zstack-fleet

zstack-fleet is a members-only add-on for the 500x Engineer Skool community. It adds the pipeline layer
for many projects and accounts: an accounts doctor, a CI cost budget and runner lint, a spot-reclaim
retry policy, a drift metric with a WIP cap, batch planning and release trains. It needs this core skill
installed; core never needs it. Members get it from the Premium section of the 500x Engineer Skool
community.

## Credits

zStack's wording and code are original. It is inspired by these projects:

- **pstack** by Lauren Tan (MIT), from `cursor/plugins`: the router with an inline principle index, a
  playbook catalog, steps copied into the todo list with skips explained, and naming the principle and
  what it changed.
- **Agensh** by Microsoft Research (MIT), "A Decentralized, Scalable Multiagent Harness": workers that
  claim sub-tasks, share findings and verify before merging. zStack's shared FAIL board, expiring
  claims and staggered lane start come from reading it.
- **David Ondrej's skills:** zStack is inspired in part by David Ondrej's agent-orchestration work
  (github.com/davidondrej/skills, MIT).
- **pstack-claude**, a port by Michael Denyer (MIT, license copyright Lauren Tan): one skills tree with thin per-harness manifests, a
  session-start routing hook, and per-harness tool mapping.
- Standards referenced: [Agent Skills](https://agentskills.io) and [AGENTS.md](https://agents.md).

Links, licenses and copyright holders are in [NOTICE](NOTICE).

## License

MIT, Copyright (c) 2026 Elon Zito. See [LICENSE](LICENSE).
