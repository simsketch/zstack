# empty-check-fails

**Rule:** A check that ran zero tests failed, whatever its exit code says.

## Why

Test runners exit 0 when they find nothing to run. An ignore rule, a wrong root directory or a new
worktree path can make a suite collect zero tests, and a build cache will happily store that result as a
pass. Every later run then reports green while testing nothing. Asserting a non-zero count is the only
way to tell "all tests passed" from "no tests ran".

## Checks

- Every recorded test check has a test count greater than zero.
- A count that cannot be parsed is reported as unknown, and is never described as passing tests.
- Checks that run no tests by nature (lint, typecheck) are recorded as such, so their missing count is
  expected.
- A new worktree or a changed test config gets one run with the count read by eye.

## Script the check

`scripts/zcheck.sh -- <cmd>` exits 3 and records a failure when the parsed count is zero (or below
`--min-tests`). Use `--no-count` for lint and typecheck.
