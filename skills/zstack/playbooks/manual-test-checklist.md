# manual-test-checklist

**Use when:** the human asks "what should I test today?", a batch of merges just finished, or tickets are
waiting in `manual-verify`.

## Inputs

- The repo (`--repo <owner/name>` when it differs from the current one).
- The time to start from (`--since <ISO time>`; the default is the last generated checklist, else 24 hours
  ago).
- `.git/zstack/smoke.md`, the repo's fixed smoke list (copy `<zstack dir>/templates/smoke.md` there and edit it if it is
  missing).

## Steps

1. Generate the checklist: `python3 <zstack dir>/scripts/checklist.py generate` (add `--since <ISO time>` or
   `--repo <owner/name>` when needed). It writes `.git/zstack/checklists/checklist-<YYYY-MM-DD>.md`.
2. Open the file and read the `## No test steps` section. For each PR listed there, add a `## How to test`
   block to the PR body (from `<zstack dir>/templates/pr-body.md`), or ask its author to, and regenerate.
3. Check the tickets waiting in `manual-verify`. The script already includes open GitHub issues with
   that label and writes their results back as issue comments. For tickets in any other tracker, append
   each by hand as `- [ ] <ticket> <title>: <steps> -> expected <x>  result:` under its environment,
   and write their results on the ticket yourself.
4. Give the human the checklist path and a one-line count: items per environment, plus the smoke list.
5. While the human tests, keep other work on things that do not need them.
6. Collect results. The human marks each item `[x]` and fills `result: pass` or `result: fail <note>`, or
   dictates notes that you write into the file the same way.
7. Preview the write-back: `python3 <zstack dir>/scripts/checklist.py record <file> --dry-run` and check the comments it
   would post.
8. Write results back: `python3 <zstack dir>/scripts/checklist.py record <file>`. Each result becomes a PR comment.
9. For each `open bug:` line it prints, open a bug ticket with the PR, the steps and the note, and start
   `bug-class-sweep` (or `debug` when the cause is unknown).
10. For each item under `## Candidate journey tests`, open a ticket to automate that journey.
11. Report: passed, failed (with ticket links), untested, and new candidate journey tests.

## Done when

The checklist file exists for today, every PR without test steps is either fixed or listed in the report,
every tested item's result is written back as a PR comment, every failure has a bug ticket, and each
candidate journey test has a ticket.

## Principles

- [`spend-attention-carefully`](../references/principles/spend-attention-carefully.md): the human gets one
  ordered list, grouped by environment, instead of PRs one by one.
- [`three-words`](../references/principles/three-words.md): a passed item is the Verified evidence for its
  PR, with who and when.
- [`fix-the-class`](../references/principles/fix-the-class.md): a failure opens a bug, which opens a sweep.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): results come from the
  human's marks, never from assumption.

## Preferred shape

Inline: the script does the gathering, and the human is in the loop for the testing itself.
