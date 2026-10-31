# Drive-by fixes

A worker that notices a defect unrelated to its task may fix it in the same PR only when **all** of
these hold:

- it touches one file, or one file plus that file's test;
- the fix has a test, or it is a pure typo, dead import or comment fix;
- the file is outside every solo class and is not leased to another lane;
- the fix is under about 20 changed lines.

When it qualifies:

1. Put it in its **own commit**, separate from the main change, with the subject prefix `drive-by:` (or
   the ticket key, if a ticket exists).
2. Add one line under `## Drive-bys` in the PR body: the file, what was wrong, and how it was checked.
3. Run the same checks as the main change; a drive-by is held to the same gates.

When it does not qualify, leave the code alone and add it under `## Follow-ups` in the PR body as a
ticket-ready entry: file:line, what is wrong, and a reproduction or the reasoning that shows it.

Drive-by commits stay separable: at merge time, or at a merge desk when zstack-fleet is installed, a
drive-by can be dropped from a PR or a batch without touching the main change. Drive-bys count in the
trust ladder like any other change, so a reverted drive-by drops its class one level too.
