# fix-the-class

**Rule:** Once a bug's cause is known, search for every other place the same cause can strike before calling the bug fixed.

## Why

Bugs come in families. The same check-then-write race, the same wrong join, the same missing guard tends
to appear wherever the same author or pattern touched the code. On a busy day, several separate PRs can
fail review for one identical race, which means fixing them one ticket at a time costs far more than
naming the pattern once and sweeping for it. A guardrail that fails on the pattern keeps the family from
growing back.

## Checks

- The class is named in one line and written as a searchable pattern (a `git grep` regex at minimum).
- Every app and package in the repo was searched, plus any sibling repos listed in `sweep_repos=`.
- Each hit is classified confirmed, suspect or safe, with a file:line and one sentence of reasoning, in a
  sweep report saved to `.git/zstack/sweeps/<date>-<class>.md` (from `templates/sweep-report.md`).
- Confirmed hits are fixed in this change or ticketed by impact; a guardrail lands in its own commit.
- Trivial one-offs carry a one-line "no class: <reason>" note instead of a sweep.
