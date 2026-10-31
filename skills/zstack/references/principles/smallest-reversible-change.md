# smallest-reversible-change

**Rule:** One ticket per change, and every commit can be reverted on its own without breaking the others.

## Why

Small, separable commits are what let a team move fast and still back out of a mistake in minutes.
When ten related tickets ride in one batch, giving each its own commit with the ticket key in the
subject means one bad ticket can be reverted alone while the other nine stay merged. A sprawling commit
forces a choice between keeping a bug and losing good work.

## Checks

- Each commit subject names one ticket or one purpose.
- Reverting any single commit leaves the build and the tests green (or the PR says which commits depend
  on each other).
- Formatting, renames and moves sit in their own commits, apart from behavior changes.
- The PR touches only files the goal needs, plus drive-bys in separate commits.
