Read the zstack router first (the zstack skill's SKILL.md), then the playbook and principle leaves named
below. Read each principle leaf before you apply it.

zstack dir: {{ZSTACK_DIR}} (scripts and templates below live there)

## Your task

Ticket: <key or link>
Goal: <one line>
Done when: <the gate, in one line>
Spec: <path to .git/zstack/specs/<ticket>.md from spec-pass, or "clear as written">
Playbook: <playbook name>[ -> <chained playbook>]
Worktree: <path>  Branch: <branch>  Base: <base>

## Principles in force

- <principle-name>: <why it applies to this task>
- <principle-name>: <why it applies>

## Files

Predicted files: <paths this task should touch>
Leased to you: <hot files you may edit, or "none">
Leased to other workers, leave alone: <paths, or "none">
If you need a file outside these lists that another worker may be editing, report it and wait.

## How to work

1. Copy the playbook's steps into your todo list word for word; keep skipped steps with a reason.
2. Stage by path, check `git diff --cached --stat` before each commit, and use WIP commits instead of
   `git stash`.
3. Record checks with `{{ZSTACK_DIR}}/scripts/zcheck.sh --name <check> -- <command>` on a clean tree at your head commit.
4. When the task leaves a product or behavior choice open and you choose rather than ask, note the
   choice and why; it goes under `## Assumptions` (`list-your-assumptions`). A guess left off that list is
   a review finding.
5. Before you finish, answer every class in `{{ZSTACK_DIR}}/references/edge-cases.md` (and
   `.git/zstack/edge-cases.md` when it exists) under `## Edge cases`: `N/A - <why>`, `covered - <test>`
   or `open - <why>` (`walk-the-edge-classes`). A class that applies gets its test in the same commit as
   the code.
6. Reuse before you write: search for an existing helper, component, constant or copy string before
   adding one, and list what you used under `## Reused`. Domain logic (business rules, money math, dates
   and time zones, permissions, masking, pricing, shared copy) lives in one place
   (`one-copy-of-domain-logic`).
7. Open the PR with the body from `{{ZSTACK_DIR}}/templates/pr-body.md` when the playbook says to. Leave merging and
   deploying to the coordinator.

## Drive-by rule

You may fix an unrelated defect in this PR only when all of these hold: it touches one file (or one file
and its test), the fix has a test or is a pure typo, dead import or comment fix, the file is outside the
solo classes and outside other workers' leases, and the change is under about 20 lines. Put it in its own
commit with the subject prefix `drive-by:` and list it under `## Drive-bys`. Anything bigger goes under
`## Follow-ups` with `path:line` and the evidence; do not start it.

## Limits

- No CI pollers: no watch commands on checks or runs. Read CI status once when asked, then report.
- No credential reads: never open, print or copy credential files, tokens or env files with secrets.
  Commands that need a secret read it inside their own process.
- Report guards: a guard, hook, permission block or limit that stops you gets reported to the coordinator
  as is. Leave it unchanged and do not look for a way around it.
- Stop processes only by the pid you captured or a path inside your own worktree.
- Use your own port, database and browser profile.
- Leave the GitHub account alone (`gh auth switch` is off limits), and skip `--no-verify`.
- When your context gets large, run the `pause` playbook and write a handoff file.

## Shared board

Before you start, read `.git/zstack/board.md` (it may not exist yet) and skip any approach already
listed there as failed. When an approach of yours fails, append one line before you try the next one:

`FAIL <ticket> <what you tried> | <why it failed> | <commit sha or log path>`

## Reporting

Report at these points, one line each: `working <what>`, `blocked <why, what you need>`,
`verifying <check>`, `pr-open <number> <head sha>`, `failed <why>`. Your final report names the
principles that shaped your decisions and what each changed.
