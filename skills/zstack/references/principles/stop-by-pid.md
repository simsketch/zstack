# stop-by-pid

**Rule:** Stop a process only by a pid you captured when you started it, or by a path inside your own worktree.

## Why

On a shared machine, a broad kill by name or port takes down other people's servers, other lanes' test
runs, or the coordinator itself. A pid you captured, or a match on your own worktree's path, limits the
blast radius to work you own. The same care applies to typing into terminals: only a live session that
you identified should receive input.

## Checks

- Every background process you start has its pid recorded where you can find it again.
- Stops use that pid, or a pattern anchored to your own worktree path, and never a bare process name.
- Before stopping a process you did not start, ask; a hung job may be stopped by pid after it has shown
  no CPU for a long stretch, and the stop is reported.
- Commands that might raise an interactive prompt in an unattended run are rewritten to avoid it.
