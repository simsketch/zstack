# walk-the-edge-classes

**Rule:** Before a change is called done, answer every class in the edge-case checklist for it, each as not applicable with a reason, covered by a named test, or open with the risk.

## Why

Most defects that pass CI and reach users are not wrong logic on the happy path. They are an older
request landing last, a step that fails halfway, a channel that is turned off, a date at midnight in
another time zone, a page that holds one row more than the limit. Authors miss them because nobody asked.
A fixed list asks every time, costs a few lines per PR, and gives the reviewer the same list to break the
change against.

## Checks

- The PR body has `## Edge cases` with one line per class in `<zstack dir>/references/edge-cases.md`, plus
  any repo classes in `.git/zstack/edge-cases.md`, by number.
- Each line is `N/A - <why>`, `covered - <test file and name>` or `open - <why no test, and the risk>`.
- A class the author was unsure about was treated as applying.
- An `open` line on money, permissions or personal data keeps the PR from merging until the human accepts
  it.
- A bug-class sweep that names a class not on the list adds it to `.git/zstack/edge-cases.md`.
