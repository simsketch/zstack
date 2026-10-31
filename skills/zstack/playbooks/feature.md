# feature

**Use when:** the goal is new behavior: a new screen, endpoint, field, job, option or integration.

## Inputs

- The request and its definition of done, in the asker's words.
- The ticket, if one exists, and any design, copy or API contract attached to it.
- The repo's own rules (CLAUDE.md, AGENTS.md, contributing docs), which outrank this playbook.

## Steps

1. Restate the feature and its definition of done in one or two lines. If done is unclear, ask the user
   one question with options before writing code.
2. Name the data first: which records or fields are created, read, changed or deleted, which module owns
   each, and where it is stored. Write this as a short list in the PR description draft.
3. Look for what already exists: a helper, component, endpoint or flag that does most of this. Reuse or
   extend it before adding a new one, and remove anything the feature makes dead.
4. Write the planned file paths one per line to a scratch file and run
   `<zstack dir>/scripts/classify.sh --files <that file>`. If the result is `solo`, the PR opens with the `hold` label
   and runs as its own piece of work.
5. Write the tests first where the repo has tests: one per behavior in the definition of done, failing for
   the right reason.
6. Implement in small ordered commits, each one leaving the build green and revertable on its own.
7. For any change that checks a value and then writes money, permissions or other contested state, add a
   concurrency test and fence the check and the write with the same lock, constraint or version check.
8. Record the checks at the head commit on a clean tree: `<zstack dir>/scripts/zcheck.sh --name <check> -- <command>`
   for tests, and `<zstack dir>/scripts/zcheck.sh --name lint --no-count -- <lint command>` for checks without a test
   count.
9. Write the PR body from `<zstack dir>/templates/pr-body.md`, including a `## How to test` block a human can follow
   without reading the code.
10. Hand over to `land`.

## Done when

Every behavior in the definition of done has a test (or a written reason why it cannot have one), the data
list is in the PR body, the checks are recorded at the head commit with non-zero test counts, and the PR
body carries a complete `## How to test` block.

## Principles

- [`data-shape-first`](../references/principles/data-shape-first.md): the work starts by naming the data
  and its owner.
- [`subtract-first`](../references/principles/subtract-first.md): existing code is reused or removed before
  new code is added.
- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): small ordered
  commits, each revertable.
- [`ask-with-options`](../references/principles/ask-with-options.md): scope and product questions go to the
  human with options and a recommendation.
- [`leave-it-better-separately`](../references/principles/leave-it-better-separately.md): unrelated fixes go
  in separate `drive-by:` commits.

## Preferred shape

Inline for a feature in one area with clear done. One subagent when it is long: spawn a background subagent
in its own worktree and keep the session free for the human. Lane when the feature splits into pieces that
each merge on their own with disjoint predicted files.
