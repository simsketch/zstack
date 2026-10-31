# refactor

**Use when:** the structure should change and the behavior should stay the same: renames, moves, splits,
merges, extracting a module, replacing a library behind the same interface.

## Inputs

- What changes shape and why (the reason decides when to stop).
- The public surface that must not change: exported APIs, routes, CLI flags, file formats, outputs.
- The tests and tools that cover that surface.

## Steps

1. Write the invariant in one line: what must behave identically before and after.
2. Check the coverage of that surface. Where tests are thin, add characterization tests first, or capture
   outputs: run a fixed set of inputs at the starting commit and save the outputs to a file outside the repo.
3. Record the baseline checks at the starting commit: `<zstack dir>/scripts/zcheck.sh --name <check> -- <command>`.
4. Delete before you move: remove dead code, unused exports and stale flags in their own commits first.
5. Make the structural change in small mechanical steps, one kind of change per commit (rename, then move,
   then split), keeping every commit green.
6. After each step run the covering tests; stop and back up one commit when one fails.
7. At the end, rerun the captured inputs and diff the outputs against the saved baseline. The diff is empty,
   or every difference is listed and explained as a bug the refactor fixed on purpose.
8. Record the same checks at the head commit with `<zstack dir>/scripts/zcheck.sh` and compare test counts with the
   baseline; a lower count needs an explanation.
9. Put the invariant, the proof (test counts before and after, the empty output diff) and the commit list
   in the PR body.

## Done when

The same checks pass at the start and head commits with equal or higher test counts, the captured-output
diff is empty or every difference is explained, and every commit is a single kind of mechanical change.

## Principles

- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): one kind of
  change per commit, so a break points at one step.
- [`subtract-first`](../references/principles/subtract-first.md): dead code goes before any move.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): "no behavior change"
  is claimed only with recorded checks and an output diff.
- [`one-owner-per-file`](../references/principles/one-owner-per-file.md): a refactor touching hot files
  takes their lease, or waits.

## Preferred shape

One subagent: spawn a background subagent in its own worktree, since refactors touch many files and
produce long test output. Run it alone (not as one lane among several) when it touches files other lanes
are likely to edit.
