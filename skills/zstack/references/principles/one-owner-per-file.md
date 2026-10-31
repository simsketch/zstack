# one-owner-per-file

**Rule:** When work runs in parallel, each hot file is leased to exactly one lane at a time.

## Why

Parallel workers that edit the same file spend their time resolving each other's conflicts. Ten tickets
on the same screens, opened as ten PRs, means every merge breaks the other nine, and most of the effort
goes into rebasing and re-running checks. Leasing files up front either keeps pieces apart or puts the
overlapping pieces in one lane where conflicts are resolved once. Checking for an existing owner before
dispatch also stops two workers from doing the same ticket.

## Checks

- Before dispatch, each piece lists its predicted files, and overlapping pieces share a lane or run in
  sequence.
- Before assigning a ticket, search open PRs, remote branches and local worktrees for its key; a hit
  means it is owned.
- A worker that needs a file outside its lease asks the coordinator instead of editing it.
- No two workers share one worktree.
- A claim on a ticket or hot file expires after about 60 minutes with no output from its holder; only
  then may another worker take it, and the hand-over is noted in the coordinator's log.
