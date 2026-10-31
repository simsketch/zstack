# spend-attention-carefully

**Rule:** Batch your questions to the human, and keep working on everything that does not depend on the answers.

## Why

Each interruption costs the human more than the question itself, and an agent that stops at its first
question leaves capacity idle. One page of batched questions, each with a default, lets the human answer
everything at once when they are free, while work that needs no answer keeps moving.

## Checks

- Open questions sit on one decision page (`.git/zstack/decisions.md`), one entry per question.
- The human gets one short message when the page changes, never one per question.
- While waiting, the todo list shows which items are blocked and which continue.
- Safe, reversible defaults proceed flagged `revisit`; protected items wait.
