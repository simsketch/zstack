# spec-pass

**Use when:** a ticket or goal is open: it has no testable definition of done, or it leaves a product
choice (behavior, copy, a default, a flow, where something lives) to whoever builds it. Runs before
`feature`, `debug` or `refactor` starts, and before an open ticket in `autopilot-queue` gets a worker.

## Inputs

- The ticket or request, in the asker's words, with anything attached to it.
- The repo's docs, existing behavior in the code, and earlier answers on the decision page.
- `<zstack dir>/references/edge-cases.md` and `.git/zstack/edge-cases.md` when it exists.

## Steps

1. Triage the goal as clear or open. Clear: done is stated in testable terms (acceptance criteria, or an
   example of the expected result) and no product choice is left to the builder. Anything else is open. A
   ticket that says what "should" happen with no example, or has no acceptance criteria, is open.
2. If it is clear, write `clear: <the testable done line>` and hand over to the playbook it routes to.
   Stop here.
3. Read-only from here on: no branch, no code change. List the open questions, one line each.
4. Answer every question the code, docs or the human's earlier words settle, and cite the source.
5. For each remaining question, propose an answer with two or three options and a recommendation.
6. Walk the edge-case classes and list the ones this ticket will hit, each with the behavior you propose.
7. Write the spec to `.git/zstack/specs/<ticket-or-slug>.md`: the testable definition of done, the
   answered questions with sources, the proposed answers, and the edge cases.
8. Send product questions to the human with `ask-with-options` (on the decision page in human-busy mode or
   inside `autopilot-queue`). Reversible questions outside the protected list may proceed on the
   recommendation, flagged `revisit`.
9. When every protected question is answered, mark the ticket clear, with the spec path, and hand over to
   the playbook it routes to. The builder copies the proposed answers it relied on into `## Assumptions`.

## Done when

The goal is marked clear with a testable definition of done, the spec file exists with every question
answered or recorded as a `revisit` default, and no question on the protected list is still open; or the
ticket is reported as waiting on named questions.

## Principles

- [`ask-with-options`](../references/principles/ask-with-options.md): product questions go to the human
  with options and a recommendation; the rest are answered from sources.
- [`list-your-assumptions`](../references/principles/list-your-assumptions.md): proposed answers the
  builder relies on become its `## Assumptions`.
- [`walk-the-edge-classes`](../references/principles/walk-the-edge-classes.md): the edge cases are decided
  before code, while they are cheap to change.
- [`spend-attention-carefully`](../references/principles/spend-attention-carefully.md): questions are
  batched, and clear tickets keep moving while open ones wait.

## Preferred shape

Inline for one ticket. For a queue, one cheap read-only subagent per open ticket (a smaller model is
enough), started a few at a time; the coordinator batches their questions onto one decision page.
