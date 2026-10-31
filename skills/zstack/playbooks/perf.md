# perf

**Use when:** something is measurably slow or expensive: a page, an endpoint, a query, a build, a test
suite, a CI run. If nobody has measured it yet, the first step below is the measurement.

## Inputs

- What is slow, where, and how slow it is said to be.
- The target, if one exists ("p95 under 300 ms", "suite under 10 minutes").
- Access to an environment where the measurement can be repeated on the same data and hardware.

## Steps

1. Write the metric in one line: what is timed, from which start event to which end event, on which data,
   on which machine or environment.
2. Build a repeatable measurement (a benchmark, a script, a saved profile command) and keep its exact
   command.
3. Record the baseline: run it at least three times at the starting commit and note the median and the
   spread.
4. Find the critical path before changing anything: profile, trace, or time the stages, and name the one
   stage that sets the total. Faster parts elsewhere leave the total unchanged.
5. Write a hypothesis for that stage ("N+1 queries in the list endpoint") and the measured gain it predicts.
6. Try removing work before adding machinery: fewer calls, less data, a skipped step, a reused result.
   Reach for caches, parallelism or bigger machines only after that.
7. Make one change at a time, each in its own commit, and remeasure with the same command on the same
   baseline after each.
8. Keep a change only when the measurement moved past the run-to-run spread; revert the rest.
9. Check that behavior held: run the area's tests through `<zstack dir>/scripts/zcheck.sh --name <check> -- <command>`.
10. Report before and after side by side: command, commit, data set, median and spread for each.

## Done when

A before and an after measurement exist from the same command, data and machine, the change in the median
is larger than the spread, each kept change is its own commit, and the area's checks are recorded at the
head commit.

## Principles

- [`numbers-from-tested-queries`](../references/principles/numbers-from-tested-queries.md): every timing in
  the report comes from the recorded command.
- [`subtract-first`](../references/principles/subtract-first.md): removing work is tried before adding a
  cache or more hardware.
- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): one change per
  commit, so a regression can be traced and reverted.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): "faster" is claimed
  only with the before and after numbers at named commits.

## Preferred shape

Inline when the measurement is quick. One subagent when profiling and repeated runs are long; spawn a
background subagent in its own worktree and keep the machine quiet while it measures (one benchmark at a
time, so runs do not distort each other).
