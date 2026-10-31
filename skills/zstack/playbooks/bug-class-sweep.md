# bug-class-sweep

**Use when:** a bug's root cause is known (usually handed over by `debug`), a bug ticket arrives, or a
manual-test failure opens a bug. The goal is to find and handle every other instance of the same mistake.

## Inputs

- The original bug: symptom, root cause, the fix commit if one exists.
- `.git/zstack/config` for `sweep_repos=` (sibling repos to search as well).
- Earlier sweeps in `.git/zstack/sweeps/`, in case a similar class was swept before.
- The lane's file lease, if this runs inside a lane.

## Steps

1. Accept the root cause from a finished `debug`, or reproduce and root-cause it first using the `debug`
   steps.
2. Decide whether a class exists. If the mistake cannot recur elsewhere (a one-character typo, a single
   wrong constant), write `no class: <reason>` in the PR body and the ticket, and stop here.
3. Name the class in one line, for example "money written after a read with no lock between".
4. Write the class as a searchable pattern. Start with a `git grep -nE '<regex>'`; move to an `ast-grep` or
   `semgrep` rule only when the regex returns too much noise. Keep the exact command.
5. Run the pattern across every app and package in this repo, then in each repo listed in `sweep_repos=`.
6. Classify every hit as confirmed, suspect or safe, each with `path:line` and one sentence of reasoning.
   Read each hit; a hit you have not opened is suspect.
7. Fix confirmed hits in this batch when they share the same fix and their files sit inside this lane's
   lease, one commit per fix. Ticket every other confirmed or suspect hit by impact, with the `path:line`
   and reasoning attached.
8. Write the "why tests and QA missed it" note: one paragraph on the gap that let the class through.
9. Add a guardrail in its own commit: a lint rule, guard test or validator that fails on the pattern.
   Prove it by running it against the unfixed code (it fails) and the fixed code (it passes), and record it
   with `scripts/zcheck.sh --name <guardrail> -- <command>`.
10. Write the report from `templates/sweep-report.md` to `.git/zstack/sweeps/<YYYY-MM-DD>-<class-slug>.md`.
11. Link the original bug, every fix commit, every ticket and the guardrail in the PR body and on the
    original ticket.

## Done when

Every hit has a classification with `path:line` and a reason, every confirmed hit is fixed or ticketed,
the guardrail exists in its own commit and was shown to fail on the unfixed pattern, the "why missed" note
is written, and the sweep report is saved under `.git/zstack/sweeps/`. For a one-off, the `no class:` note
is in the PR body and the ticket.

## Principles

- [`fix-the-class`](../references/principles/fix-the-class.md): the known cause drives a search for its
  siblings across apps and listed repos.
- [`one-owner-per-file`](../references/principles/one-owner-per-file.md): hits outside this lane's lease
  become tickets instead of edits.
- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): one commit per
  fix and one for the guardrail, so each can be reverted alone.
- [`numbers-from-tested-queries`](../references/principles/numbers-from-tested-queries.md): the hit counts in
  the report come from the recorded search command.
- [`leave-it-better-separately`](../references/principles/leave-it-better-separately.md): unrelated defects
  found while sweeping follow the drive-by rule.

## Preferred shape

One subagent for a single repo: spawn a background subagent in its own worktree with the class and pattern
in its brief. Lane when the sweep spans sibling repos or several areas with disjoint files, one worker per
repo or area and the coordinator merging the reports.
