# name-what-changed

**Rule:** Every final reply and PR body names the principles that shaped the work and what each one changed.

## Why

Naming the effect of each principle is what makes the method reviewable. A line like
"reproduce-first: added a failing test before touching the parser" tells a reviewer what to check and
lets them spot a principle that was named and ignored. Over many PRs, the same lines show which
principles earn their keep.

## Checks

- The reply or PR body has one line per cited principle in the form `<name>: <what it changed>`.
- Only principles whose leaf was read this session are cited.
- A principle that was considered and set aside says why in the same line.
- The route line appears in the PR body under `## Route`.
