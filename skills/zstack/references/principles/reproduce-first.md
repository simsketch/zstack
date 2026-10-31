# reproduce-first

**Rule:** No fix lands before you have reproduced the bug, or written down why a reproduction is impossible.

## Why

A fix written against a guess can pass review and still leave the bug in place, because nobody saw it
fail in the first place. A reproduction turns the bug into something you can watch go from failing to
passing, and it usually becomes the regression test for free. When a reproduction truly cannot be had
(production-only data, a race that needs real load), the written reason tells the reviewer how much
weight the fix can bear.

## Checks

- A command, test or set of steps that shows the failure is recorded before the first code change.
- The same reproduction passes after the fix, at the head commit, and the output is quoted in the PR.
- Where the repo has tests, the reproduction lives on as a test that failed before the fix.
- If no reproduction exists, the PR says why in one or two sentences and names what evidence was used
  instead.
