# debug

**Use when:** something behaves wrongly and the cause is unknown: a failing test, an error report, a
crash, a wrong value on a screen. When the cause is already known, go straight to `bug-class-sweep`.

## Inputs

- The symptom: what happened, what was expected, where (environment, platform, screen or endpoint).
- Any evidence already gathered: error text, logs, a ticket, steps from the reporter.
- The commit or deploy where it was first seen, if known.

## Steps

1. Write the symptom as one line: observed, expected, where.
2. Reproduce it. Prefer a failing automated test; fall back to a script or a recorded manual sequence. If
   it cannot be reproduced, write down what you tried and why, and ask the user before going further.
3. Shrink the reproduction until every remaining step is needed to trigger it.
4. List at least two candidate causes and the observation that would tell them apart.
5. Run those observations (logging, a debugger, `git bisect run <repro>` when a known good commit exists)
   until one cause is left standing. Record the evidence that ruled out each other candidate.
6. Name the root cause in one sentence that explains every observed symptom. A cause that leaves a symptom
   unexplained is a partial cause; return to step 4.
7. Make sure the reproduction is captured as a test that fails on the current code.
8. Make the smallest change that fixes the root cause, in its own commit.
9. Record the checks at the fix commit on a clean tree: `<zstack dir>/scripts/zcheck.sh --name <check> -- <test command>`
   for the new test and the suite that covers the area. A check that ran zero tests failed.
10. Confirm the original symptom is gone the way it was first seen (same environment, same steps).
11. Chain into `bug-class-sweep` with the root cause as its input. When the bug is a true one-off (a typo,
    a single wrong constant), write `no class: <reason>` in the PR body instead.

## Done when

A test that failed before the fix passes after it, the checks are recorded at the head commit with a
non-zero test count, the root cause is written down with the evidence that ruled out the alternatives, and
either `bug-class-sweep` has started or a `no class:` note explains why it is skipped.

## Principles

- [`reproduce-first`](../references/principles/reproduce-first.md): no fix is written until the bug fails
  on demand, or the reason it cannot is recorded.
- [`fix-the-class`](../references/principles/fix-the-class.md): the root cause opens a sweep for its
  siblings.
- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): the fix is one
  revertable commit.
- [`empty-check-fails`](../references/principles/empty-check-fails.md): a green run with zero tests counts as
  a failure.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): "fixed" is said only
  with the recorded check at a named commit.

## Preferred shape

One subagent: spawn a background subagent in its own worktree so the reproduction, logs and bisect output
stay out of the coordinating session. Inline when the bug is small and the reproduction is already a test.
