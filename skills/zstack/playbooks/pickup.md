# pickup

**Use when:** taking over work another agent or session started: a paused branch, a stuck worker's
worktree, a PR someone else opened, or "carry on where we left off".

## Inputs

- The branch, worktree, PR or ticket to take over.
- The handoff file, if one exists (`.git/zstack/handoffs/<branch>.md`, or the body of the last
  `wip:` commit).

## Steps

1. Confirm the work is yours to take: no other live session is on this branch or worktree (a worker counts
   as live when it produced output in the last 10 minutes). If one is, stop and report.
2. Read the state from disk, in this order: the handoff file, `git log --oneline <base>..HEAD`,
   `git status`, the PR body and its review threads, `.git/zstack/decisions.md` for entries on this work,
   and `scripts/zcheck.sh --list` for checks already recorded.
3. Compare the handoff with what is on disk. Note any difference (a commit the handoff does not mention,
   a check recorded at an older sha), and treat the disk as the truth.
4. Read the zstack router and the principle leaves the handoff names before applying them.
5. Restate the plan before any edit: goal and done, route line, the remaining todo list copied from the
   playbook, what you will do first, and anything you are not sure of.
6. Settle open questions that the code, docs or earlier messages can answer, citing the source. Put the
   rest on the decision page or ask the user with options.
7. If the last commit is a `wip:` commit, keep it as the base for further commits and squash or reword it
   when the work is ready to land.
8. Continue with the named playbook from the first unfinished step.

## Done when

The plan is restated (goal, done, route line, remaining steps) before any file is edited, every
difference between the handoff and the disk is noted, and work has resumed from the first unfinished step
of the named playbook.

## Principles

- [`count-the-living`](../references/principles/count-the-living.md): an earlier owner counts as gone only
  without recent output.
- [`one-owner-per-file`](../references/principles/one-owner-per-file.md): one owner per branch at a time.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): the handoff's claims
  are checked against git and the check records.
- [`ask-with-options`](../references/principles/ask-with-options.md): questions the disk cannot answer go to
  the human with options.

## Preferred shape

Inline, so the restated plan is visible to the human. Pickups inside a lane are done by a fresh background
subagent in the same worktree, started by the coordinator.
