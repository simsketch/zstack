# Trigger test results

Editor's note: recorded outputs are verbatim except that status icons in `claude/06.txt` and `claude/09.txt` were
replaced with the words `[done]` and `[warning]`, and one clause in `claude/09.txt` about the tester's personal config was
removed (marked in place).

Run on 2026-10-30 with `run-trigger-tests.sh claude` and `run-trigger-tests.sh codex`, one fresh
`acme-notes` demo repo per prompt, the skill linked at project level only (`.claude/skills/zstack` or
`.agents/skills/zstack`), stdin closed, a 600-second timeout, and the suffix "Dry run: give the route line
and your todo list, then stop before editing any files."

- Claude Code 2.1.314: `claude -p --permission-mode plan`, with Edit, Write, NotebookEdit and Agent
  disallowed, so every run reports "no subagent tool" and plans inline or headless.
- Codex CLI 0.163.0: `codex exec --skip-git-repo-check -s read-only`.
- Both ran with the tester's normal user configuration (other skills and plugins installed), so zStack
  competed with other skills for each prompt.

Every run exited 0 and no run edited a repo file. Per-run outputs are in `claude/NN.txt` and
`codex/NN.txt`; the header of each lists the zstack files the agent read.

"Fired" means the agent loaded the zstack skill (Claude: a Skill tool call for `zstack`; Codex: it read
`skills/zstack/SKILL.md`) and gave a route line. "Todo" compares the list with the chosen playbook's
steps: **verbatim** (word for word), **condensed** (every step present in order, some reworded or
shortened), or **partial** (the first playbook copied, a chained one summarized).

Result: **20 of 20 PASS** (10 Claude Code, 10 Codex). One router sentence was added after the first run
and prompt 06 was rerun on both harnesses (see Observations).

## Claude Code

| # | Prompt (short) | Fired | Route line (verbatim) | Todo | Result |
|---|---|---|---|---|---|
| 01 | zstack: CSV export drops the last row | yes | `Route: debug -> bug-class-sweep -> land, shape: inline, principles: reproduce-first, fix-the-class, smallest-reversible-change, evidence-before-the-word` | verbatim (debug, bug-class-sweep; land deferred) | PASS |
| 02 | CSV export dropping rows, cause unknown | yes | `Route: debug -> bug-class-sweep -> land, shape: inline, principles: reproduce-first, fix-the-class, smallest-reversible-change, empty-check-fails, evidence-before-the-word` | condensed, with planned actions per step | PASS |
| 03 | zstack: review branch feature/tags | yes | `Route: review, shape: inline, principles: evidence-before-the-word, empty-check-fails, report-the-guard, secrets-stay-in-process, fix-the-class` | verbatim; step 10 marked likely skipped (no PR) | PASS |
| 04 | Add a tags field | yes | `Route: feature -> land, shape: inline, principles: data-shape-first, subtract-first, smallest-reversible-change, ask-with-options, leave-it-better-separately, name-what-changed` | verbatim; step 7 skipped with reason | PASS |
| 05 | What should I test today? | yes | `Route: manual-test-checklist, shape: inline, principles: spend-attention-carefully, three-words, fix-the-class, evidence-before-the-word` | verbatim | PASS |
| 06 | Testing on my phone for two hours (rerun) | yes | `Route: pickup -> feature -> land (inside human-busy), shape: inline, principles: spend-attention-carefully, ask-with-options, count-the-living, one-owner-per-file, data-shape-first, smallest-reversible-change, evidence-before-the-word, name-what-changed` | condensed, all four playbooks, skip explained | PASS |
| 07 | Is the CSV fix live in production? | yes | `Route: verify-release, shape: inline, principles: three-words, evidence-before-the-word, secrets-stay-in-process, ask-with-options` | verbatim | PASS |
| 08 | zstack: three independent tickets in parallel | yes | `Route: autopilot-queue -> feature (x2) + land, shape: lane (2 lanes, capped from 3), principles: one-owner-per-file, smallest-reversible-change, data-shape-first, subtract-first, rebase-once-late, evidence-before-the-word, leave-it-better-separately, name-what-changed` | condensed (12 steps in order, steps 4-12 reworded) | PASS |
| 09 | Take over wip/search | yes | `Route: pickup -> feature -> land, shape: inline, principles: count-the-living, one-owner-per-file, evidence-before-the-word, ask-with-options, data-shape-first, smallest-reversible-change` | condensed (pickup and feature, with status per step) | PASS |
| 10 | list command is slow | yes | `Route: perf -> land, shape: inline, principles: numbers-from-tested-queries, subtract-first, smallest-reversible-change, evidence-before-the-word` | verbatim, with planned actions per step | PASS |

## Codex

| # | Prompt (short) | Fired | Route line (verbatim) | Todo | Result |
|---|---|---|---|---|---|
| 01 | zstack: CSV export drops the last row | yes | `Route: debug -> bug-class-sweep, shape: inline, principles: reproduce-first, fix-the-class, evidence-before-the-word` | verbatim (debug and bug-class-sweep) | PASS |
| 02 | CSV export dropping rows, cause unknown | yes | `Route: debug -> bug-class-sweep, shape: inline, principles: reproduce-first, fix-the-class, evidence-before-the-word` | verbatim (debug and bug-class-sweep) | PASS |
| 03 | zstack: review branch feature/tags | yes | `Route: review, shape: inline, principles: evidence-before-the-word, empty-check-fails, report-the-guard, secrets-stay-in-process, fix-the-class` | verbatim; step 10 skipped with reason | PASS |
| 04 | Add a tags field | yes | `Route: feature, shape: inline, principles: data-shape-first, subtract-first, smallest-reversible-change` | verbatim; step 7 skipped with reason | PASS |
| 05 | What should I test today? | yes | `Route: manual-test-checklist, shape: inline, principles: spend-attention-carefully, three-words, fix-the-class, evidence-before-the-word` | verbatim | PASS |
| 06 | Testing on my phone for two hours (rerun) | yes | `Route: human-busy -> autopilot-queue, shape: inline, principles: spend-attention-carefully, ask-with-options, smallest-reversible-change, evidence-before-the-word` | verbatim (both playbooks), deferrals explained | PASS |
| 07 | Is the CSV fix live in production? | yes | `Route: verify-release, shape: inline, principles: three-words, evidence-before-the-word` | verbatim; step 8 skipped with reason | PASS |
| 08 | zstack: three independent tickets in parallel | yes | `Route: autopilot-queue, shape: lane, principles: one-owner-per-file, smallest-reversible-change, evidence-before-the-word` | verbatim (12 steps) | PASS |
| 09 | Take over wip/search | yes | `Route: pickup -> feature -> land, shape: inline, principles: count-the-living, one-owner-per-file, evidence-before-the-word, data-shape-first, smallest-reversible-change` | partial: pickup verbatim, feature summarized in one line | PASS |
| 10 | list command is slow | yes | `Route: perf, shape: inline, principles: numbers-from-tested-queries, subtract-first, smallest-reversible-change, evidence-before-the-word` | verbatim | PASS |

## Observations and concerns

- **Suffix wording.** The runner's suffix says "stop before editing any files"; the original brief said
  "stop before editing files". The one-word difference was kept so the script matches these results.
- **Unprompted triggering works on both harnesses.** The seven prompts that do not name zstack (02, 04,
  05, 06, 07, 09, 10) all loaded the skill.
- **Prompt 06 was the one routing fix.** In the first run Claude Code put `human-busy` first, while
  Codex applied the walk-away override and routed `autopilot-queue -> human-busy`. SKILL.md step 2 then
  gained one sentence: human-busy mode wraps the work, and the work itself routes by the normal rules.
  Prompt 06 was rerun on both harnesses (the rows above are the rerun). Both now treat human-busy as the
  outer mode: Claude Code routes the single open ticket through `pickup -> feature -> land` inside it,
  and Codex routes `human-busy -> autopilot-queue`.
- **Prompt 08 on Codex missed the file overlap.** Claude Code found that `--version` and JSON export both
  edit `acme_notes/cli.py` and capped three lanes to two (one-owner-per-file); Codex planned three
  workers without that check. Its todo list still contains step 3 (predict files, group overlaps), so
  the check would happen at run time; the dry run stopped before it.
- **Codex drops the chained `land` from the route line** for feature and perf (04, 10). SKILL.md says
  work ending in a PR continues into `land`, so this is a cosmetic gap.
- **Claude Code tends to condense steps** after the first few (02, 06, 08, 09) instead of copying every
  step word for word; every step is still present and in order. Codex copied verbatim in 9 of 10.
- **Both found the planted bugs** while planning: the CSV off-by-one, the sibling in `list --limit`
  (named as a drive-by or follow-up in Claude 04, 08, 09, 10 and Codex 04), and the README typo.
  Claude 09 also noticed the WIP commit was seconds old and, citing `count-the-living`, asked before
  taking over; that is an artifact of the demo repo being built just before the run.
- **Environment notes, not skill issues.** Plan mode in Claude Code tried to save a plan file under
  `~/.claude/plans/` and was refused; one Codex run
  (06, both runs) hit a read-only sandbox error from a shell wrapper on the tester's machine and reported it
  instead of working around it (`report-the-guard`).
