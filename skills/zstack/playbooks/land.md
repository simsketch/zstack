# land

**Use when:** work is ready to become a PR, or an open PR is ready to merge. This playbook opens the PR
with its evidence packet and, where the trust ladder allows, merges it pinned to the verified head.

## Inputs

- The branch with the finished work.
- The base branch (`base=` in `.git/zstack/config`, default `main`).
- The route line, the principles applied, and the ticket.
- `.git/zstack/classes.conf` and `.git/zstack/config` (run `<zstack dir>/scripts/classify.sh --init` once if
  `classes.conf` is missing).

## Steps

1. Shape the commits: small, ordered, each one green and revertable. Drive-by fixes sit in their own
   commits with the `drive-by:` subject prefix. Check staged content with `git diff --cached --stat`
   before each commit.
2. Confirm the tree is clean (`git status --porcelain` prints nothing) and write down the head sha.
3. Record every required check at that sha: `<zstack dir>/scripts/zcheck.sh --name <check> -- <command>` for test runs,
   with `--no-count` for lint or typecheck. A record with zero tests failed.
4. Compute the class: `<zstack dir>/scripts/classify.sh --base <base>`. You may raise it by hand; you never lower it.
5. Write the PR body from `<zstack dir>/templates/pr-body.md`: what changed, the route line, principles and what each
   changed, evidence (check names, test counts and the head sha, then Implemented, Deployed and Verified on
   separate lines), the `## How to test` block, `## Assumptions`, `## Edge cases`, drive-bys and
   follow-ups. When an assumption is a product call, add `--label hold` in step 6 and put the question
   to the human with `ask-with-options`.
6. Read the class's effective level from the `effective` column of
   `<zstack dir>/scripts/trust.sh --class <class>`, then open the PR:
   `gh pr create --base <base> --body-file <file>`. Add `--label hold` when the class is `solo`. At L0
   (the solo default), open it with `--draft --label hold` and stop here: never mark it ready, remove
   `hold` or merge. Report the draft to the human, who takes it over. If `gh` refuses the label because
   the repo has none, report it and ask the human to create it (`gh label create hold`); never drop the
   label to get the PR open.
7. Before any merge, confirm the head has not moved: compare `gh pr view <n> --json headRefOid` with the
   recorded sha. If it moved, return to step 2.
8. Verify the records: `<zstack dir>/scripts/zcheck.sh --verify <sha> <check> [<check>...]` exits 0. Rerun
   `<zstack dir>/scripts/classify.sh --pr <n>` at the head; a riskier class than before moves the PR up before merge.
9. Check the gate: `<zstack dir>/scripts/trust.sh --gate <class>`. Exit 0 (effective level L2 or higher) lets zStack
   merge; any other result means the PR waits for the human, and you report it as ready with its evidence.
10. Merge only when the gate passed, CI is green on that same sha (one read of
    `gh pr view <n> --json headRefOid,statusCheckRollup` shows the recorded sha and every required check
    passing), any `hold` label was removed by a human, and no other merge is running in this repo (only
    the coordinating session merges, one PR at a time):
    `gh pr merge <n> --match-head-commit <sha>` with the repo's merge method flag. With zstack-fleet
    installed (its folder is `~/.agents/skills/zstack-fleet` or `~/.claude/skills/zstack-fleet`), run
    `<fleet dir>/scripts/release.sh is-frozen` right before the merge. Exit 0 means a freeze is on and
    exit 1 means clear; on exit 0 or any other exit, wait and report it instead of merging.
11. Log the merge:
    `python3 <zstack dir>/scripts/ledger.py add --pr <n> --sha <merge sha> --class <class> --checks <a,b>`.
12. Update the PR (or ticket) with the merge sha as Implemented. Deployed and Verified stay open until
    `verify-release` proves them.

## Done when

The PR body carries the full evidence packet for the current head sha, `<zstack dir>/scripts/zcheck.sh --verify` passed at
that sha, and either the PR merged through `gh pr merge --match-head-commit <sha>` with a ledger entry, or it
is reported to the human as ready because the trust gate kept the merge with them or an assumption waits on
them, or (at L0) it is open
as a draft labelled `hold` and handed to the human.

## Principles

- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): small ordered
  commits, each revertable.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): the merge happens only
  against recorded checks at the exact head.
- [`three-words`](../references/principles/three-words.md): a merge is Implemented; deployed and verified
  are reported later and separately.
- [`empty-check-fails`](../references/principles/empty-check-fails.md): zero tests blocks the merge.
- [`report-the-guard`](../references/principles/report-the-guard.md): a refused merge, failing branch
  protection or `hold` label is reported, and no flag routes around it.
- [`name-what-changed`](../references/principles/name-what-changed.md): the PR body says what each cited
  principle changed.

## Preferred shape

Inline: landing is short and the session should see each gate result. In a lane, the coordinator runs
`land` for each PR one at a time, oldest first.
