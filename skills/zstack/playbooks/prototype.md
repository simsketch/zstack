# prototype

**Use when:** the question is "which approach?": two or more designs, libraries, data models or
algorithms are plausible and reading alone will not settle it.

## Inputs

- The decision to make, in one line.
- The candidate approaches (two to four).
- The constraints that matter: speed, cost, size, effort to maintain, compatibility.

## Steps

1. Write the decision and the criteria before building anything, with how each criterion is measured and
   which result would pick each candidate.
2. Cut the comparison to the smallest slice that exercises the criteria (one endpoint, one screen, one
   data set). Everything outside that slice is out of the prototype.
3. Build each candidate on its own throwaway branch in its own worktree, named `proto/<decision>-<candidate>`.
   Prototype code never merges.
4. Measure every candidate with the same commands and data, and keep the commands.
5. Fill a comparison table: candidate by criterion, with the measured value and the command behind it.
6. Pick one and write the reasoning in two or three sentences, including what would make you revisit it.
7. If the choice touches product, money, data deletion, security or production, ask the user with the
   table, the options and your recommendation, and wait for the answer.
8. Record the decision where the repo keeps decisions (an ADR folder or design doc), or in
   `.git/zstack/decisions.md` with status `decided`, including the table.
9. Delete the prototype branches and worktrees, then route the real work to `feature` or `refactor` with
   the decision as input.

## Done when

The comparison table exists with measured values for every candidate, the decision and its reasoning are
recorded, any protected-topic choice has the human's answer, and the prototype branches are removed.

## Principles

- [`numbers-from-tested-queries`](../references/principles/numbers-from-tested-queries.md): every cell in
  the comparison comes from a recorded command.
- [`ask-with-options`](../references/principles/ask-with-options.md): protected choices go to the human
  with the table and a recommendation.
- [`subtract-first`](../references/principles/subtract-first.md): the slice is cut to the minimum that
  answers the question.
- [`name-what-changed`](../references/principles/name-what-changed.md): the decision record says which
  principle tipped the choice.

## Preferred shape

Lane: spawn one background subagent per candidate, each in its own worktree, so the candidates are built in
parallel on equal terms. Inline when there are two small candidates or the harness has no background
subagents (build them in sequence).
