# verify-release

**Use when:** someone asks "is it live?", "did it ship?", "is it deployed?", or a ticket is about to be
closed as done. The answer is the three evidence words, each with its own proof.

## Inputs

- The change: PR number, ticket, or commit.
- The environment(s) in question (dev, staging, production) and the app or service the change touched.
- How the repo exposes what is running: a version or health endpoint, an image tag, a deploy log or
  release record.

## Steps

1. Find the change commit: the merge commit or the squashed commit on the base branch
   (`gh pr view <n> --json mergeCommit,mergedAt`). No merge means Implemented is "no", and the report ends
   there.
2. Name the app or service the change touched. When a merge touched several, check each one separately;
   proof for one app says nothing about another.
3. For each environment, find the commit the serving artifact was built from: a version endpoint, the
   image tag or label, or the deploy record. Write down where the value came from.
4. Prove it contains the change: `git merge-base --is-ancestor <change sha> <serving sha>` exits 0. A green
   workflow, a tag or a merged PR on its own is not proof of deployment.
5. Check the behavior there: follow the PR's `## How to test` block in that environment, or run its smoke
   journey, and note who checked, when, and the result.
6. For production, confirm health returns success and the production invariants the repo defines (named
   config flags and their required values) hold. Read flag names and non-secret values only.
7. Report three separate lines:
   - Implemented: yes/no, merge sha.
   - Deployed: per environment, yes/no, serving sha and where it was read.
   - Verified: per environment, yes/no, who, when, what was checked.
8. Write the same three lines on the ticket and the PR. Promoting to production stays with the human
   unless the repo records a delegation; this playbook reports and never promotes.

## Done when

The three lines are written with machine evidence: a merge sha for Implemented, an `--is-ancestor` exit 0
against a named serving sha for each Deployed environment, and a named person and time for each Verified
environment. Any line without its proof says "no" or "unknown".

## Principles

- [`three-words`](../references/principles/three-words.md): implemented, deployed and verified are reported
  on separate lines.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): "live" or "shipped"
  needs the serving artifact to contain the commit.
- [`secrets-stay-in-process`](../references/principles/secrets-stay-in-process.md): invariant checks read
  flag names and non-secret values only.
- [`ask-with-options`](../references/principles/ask-with-options.md): a production promotion is the human's
  call, offered with what dev showed.

## Preferred shape

Inline: the checks are short commands and the human usually wants the answer in the session.
