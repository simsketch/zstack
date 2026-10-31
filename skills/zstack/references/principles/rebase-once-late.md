# rebase-once-late

**Rule:** Rebase a branch once, at merge time, and merge the oldest ready PR first.

## Why

Refreshing every open PR from main on each merge restarts every PR's checks at once: one workflow that
did this pushed dozens of PRs back into CI on every merge and multiplied the machine count. Rebasing once,
just before a PR merges, spends that cost only on the PR about to land. Oldest-first keeps the queue
fair and stops long-waiting work from drifting further from main.

## Checks

- No automation or step rebases or merges main into the whole queue.
- A branch is rebased only when it is next to merge, or when a conflict blocks review.
- Ready PRs merge oldest first unless the human sets another order.
- PRs much older than main's recent history are rebuilt on current main or closed with a note.
