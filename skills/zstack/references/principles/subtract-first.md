# subtract-first

**Rule:** Before adding code, config, a dependency or a pipeline step, try removing or reusing something that already exists.

## Why

Each addition fixes the last problem and often causes the next one. A pipeline that gains a merge train,
an auto-rebase job, a run cap and a re-queue sweep in two days ends up with the pieces deadlocking each
other and polling until the API budget runs out. The cheapest durable fix was one required check, one
merge path, and letting the runner queue. Asking "what can go?" first keeps systems small enough to
reason about.

## Checks

- The plan names at least one existing function, component or tool that was considered for reuse.
- New dependencies are justified in one line each, with the alternative that was rejected.
- When this is the third patch to the same mechanism, stop and propose a simplification instead.
- Net line count and the number of moving parts are reported for refactors and pipeline changes.
