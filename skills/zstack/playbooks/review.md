# review

**Use when:** a PR, branch or diff needs a review, including a second-agent verification inside
`autopilot-queue` and the delta review after a push to a held PR.

## Inputs

- The PR number, branch or diff, and the base it targets.
- The ticket or description that says what the change is meant to do.
- For a delta review: the commit that was last reviewed.

## Steps

1. Get the diff with git access in a worktree of the branch (`gh pr checkout <n>` or
   `git diff <base>...<head>`). A review without the diff in hand returns no verdict.
2. Write down the head sha being reviewed. For a delta review, review only `git diff <last-reviewed>..<head>`.
3. Run `<zstack dir>/scripts/classify.sh --pr <n>` (or `--base <base>`). If the class is `solo`, confirm the PR carries
   the `hold` label.
4. If the diff touches auth, permissions, secrets, payments, crypto, input parsing at a trust boundary or
   infrastructure, and the `ship-secure` skill is installed, hand that part to it and include its findings.
   Without it, review those parts against the checklist in step 6 with extra care.
5. Read the change against its stated intent: does it do what the ticket says, and only that?
6. Check, in this order: correctness (edge cases, error paths, off-by-one, nulls), check-then-write races on
   money or permissions (a concurrency test must exist), data shape and migrations, security (input
   handling, secrets in code or logs, authorization on every new path), tests (they fail without the
   change, and the count is non-zero), and readability.
7. Run the repo-wide guard tests and the area's tests yourself and record them:
   `<zstack dir>/scripts/zcheck.sh --name <check> -- <command>`. Check the PR's own claims against the records with
   `<zstack dir>/scripts/zcheck.sh --list <head sha>`.
8. Write findings by severity: blocker, major, minor, nit. Each has `path:line`, what is wrong, why it
   matters, and a suggested fix.
9. Give one verdict, exactly one of: `PASS`, `CHANGES NEEDED`, `FIX FIRST`. `FIX FIRST` means a blocker
   that must be fixed before anything else is reviewed; `CHANGES NEEDED` means majors or minors to address.
10. Post the review on the PR (`gh pr review <n> --comment --body-file <file>`), naming the head sha the
    verdict applies to. A later push needs a new verdict for the new commits.

## Done when

A single verdict (`PASS`, `CHANGES NEEDED` or `FIX FIRST`) is posted for a named head sha, every finding has
a severity and `path:line`, security-sensitive parts were reviewed (by `ship-secure` when installed), and
the checks the reviewer ran are recorded at that sha.

## Principles

- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): "passing" in a review
  points at a recorded check at the reviewed sha.
- [`empty-check-fails`](../references/principles/empty-check-fails.md): a suite that ran zero tests is a
  finding.
- [`report-the-guard`](../references/principles/report-the-guard.md): a change that weakens a guard, hook or
  limit is a blocker.
- [`secrets-stay-in-process`](../references/principles/secrets-stay-in-process.md): secrets printed,
  logged or committed are a blocker.
- [`fix-the-class`](../references/principles/fix-the-class.md): a defect found in review is checked for
  siblings in the same diff.

## Preferred shape

One subagent: spawn a background subagent in its own worktree of the branch, with shell and git access, so
the review is independent of the author's session. Inline only when the session reviewing did not write the
change.
