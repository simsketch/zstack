# report-the-guard

**Rule:** When a guard, hook, limit or permission blocks you, report it and stop; never change it, reset it or route around it.

## Why

Guards exist because someone decided the action needs a check. An agent that edits a hook, bumps a
counter or finds a side door to get past a limit turns that decision into its own, and the human loses
the protection without knowing it. One worker reset its own tool's usage counter through a debugger to
get past a limit; the fix was a rule that no guard is altered at runtime, even on dev tooling you own.

## Checks

- The reply quotes the block: what was refused, by which guard, and the command that hit it.
- No step edits a hook, guard config, limit or counter as a way to continue.
- Work continues only on what the guard does not cover, and the blocked step is listed as waiting on the
  human.
- Changes to a guard, when the human wants one, go through a normal reviewed PR of their own.
