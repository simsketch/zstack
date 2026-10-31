# babysit-pr

**Use when:** an open PR needs to be driven to merge-ready: it is behind the base, has conflicts, has
unanswered review threads, or has failing or missing checks.

## Inputs

- The PR number.
- The repo's base branch (`base=` in `.git/zstack/config`, default `main`).
- The PR's ticket and its `## How to test` block.

## Steps

1. Read the PR's state once: `gh pr view <n> --json headRefOid,mergeable,mergeStateStatus,reviewDecision,labels`
   and `gh pr checks <n>`. Write down the head sha.
2. Confirm nobody else is working on it: no other open worktree on this branch and no other agent named in
   recent PR comments. If someone is, stop and report.
3. Check out the branch in its own worktree. Use WIP commits for any pause; leave stash alone.
4. If the PR is behind or conflicting, rebase once onto the current base. Resolve conflicts by reading both
   sides; after the rebase, run the duplicate-key and schema validators for catalogs and config files the
   repo has, since a clean text merge can still duplicate data.
5. For each unresolved review thread: make the change in its own commit and reply with the commit sha, or
   reply with the reason it was not changed. Questions about product or scope go to the user with options.
6. For each failing check: read the log, reproduce locally, fix in its own commit. A failure unrelated to
   this PR gets reported with evidence, and stays out of this PR.
7. Record every required check at the new head on a clean tree: `scripts/zcheck.sh --name <check> -- <command>`.
8. Push once, after the local checks pass.
9. For CI, read the status once per wake-up. Schedule a wake-up for later rather than watching; continuous
   watch commands are off limits.
10. If the PR carries `hold` and anything was pushed after a review, ask for a delta review (`review` on
    the new commits) before the hold can come off. Lanes never remove `hold` themselves.
11. Update the PR body's `## Evidence` section with the new head sha and check records.

## Done when

The PR is mergeable against the current base, every review thread has a reply, every required check is
recorded at the head sha with exit 0 on a clean tree, CI is green on that same sha, and the PR body's
evidence names that sha. Then hand over to `land`.

## Principles

- [`rebase-once-late`](../references/principles/rebase-once-late.md): one rebase onto the current base, close
  to merge time.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): "green" means recorded
  checks and CI at the head sha.
- [`spend-attention-carefully`](../references/principles/spend-attention-carefully.md): CI is read on
  wake-ups, so no session sits polling.
- [`report-the-guard`](../references/principles/report-the-guard.md): a blocked push, failing hook or branch
  protection gets reported as is.
- [`one-owner-per-file`](../references/principles/one-owner-per-file.md): one agent per PR at a time.

## Preferred shape

One subagent: spawn a background subagent in its own worktree for the PR and keep the session as the
coordinator. Lane when several PRs need the same treatment, one worker per PR, processed oldest first.
