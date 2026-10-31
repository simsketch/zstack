# leave-it-better-separately

**Rule:** Fix a small unrelated defect you notice in its own `drive-by:` commit when it passes the drive-by test; otherwise ticket it with evidence.

## Why

Agents read a lot of code and notice a lot of small problems. Ignoring them wastes the find, and folding
them into the main change makes the change harder to review and to revert. A separate, tagged commit
keeps the improvement visible and removable on its own, and the size limit keeps a drive-by from turning
into an unreviewed second feature.

## Checks

- The fix touches one file (or one file plus its test), is under about 20 changed lines, and has a test
  or is a pure typo, dead import or comment fix.
- The file is outside solo classes and is not leased to another lane.
- The commit subject starts with `drive-by:` (or the ticket key) and the PR lists it under `## Drive-bys`.
- Anything larger is listed under `## Follow-ups` with file:line and a reproduction or reasoning.

See `references/drive-by.md` for the full rule.
