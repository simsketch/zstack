# Harness capabilities

zStack's skill text uses capability words. This file is the only place that maps them to the tool names
each harness uses. Harness tools change between releases; when a name here does not match what you see,
trust your harness and use the fallback.

Status: **Claude Code** and **Codex** are tested. **Cursor**, **Gemini CLI**, **OpenCode** and **Pi** are
documented, best effort.

## Capability words

| Capability word | Meaning |
|---|---|
| spawn a background subagent | start a worker that runs while this session keeps going |
| in its own worktree | the worker edits a separate `git worktree`, never this checkout |
| ask the user | a question that waits for the human, ideally with selectable options |
| keep a todo list | a visible, ordered list of steps with status |
| schedule a wake-up | resume this session later without the human typing |
| run headless | a one-shot, non-interactive run of the agent from a shell |
| run a shell command | execute a command and read its output |

## Claude Code (tested)

| Capability | Tool or command |
|---|---|
| spawn a background subagent | the `Agent` tool (older builds: `Task`) with `run_in_background: true` |
| in its own worktree | `isolation: "worktree"` on the `Agent` tool, or `git worktree add` before spawning |
| ask the user | `AskUserQuestion` |
| keep a todo list | `TodoWrite` (newer builds: the task list tools) |
| schedule a wake-up | `ScheduleWakeup` inside `/loop`, or a cron-style schedule where available |
| run headless | `claude -p "<prompt>"` with stdin closed and a timeout |
| run a shell command | `Bash` |

## Codex (tested)

| Capability | Tool or command |
|---|---|
| spawn a background subagent | `spawn_agent` when multi-agent is enabled; otherwise run headless in a second shell |
| in its own worktree | `git worktree add ../<repo>-<slug> -b <branch>` before spawning, then point the worker at it |
| ask the user | a plain message that lists the options and stops for a reply |
| keep a todo list | `update_plan` |
| schedule a wake-up | none built in; fallback below |
| run headless | `codex exec "<prompt>"` with stdin closed and a timeout |
| run a shell command | the shell tool |

## Cursor (documented, best effort)

| Capability | Tool or command |
|---|---|
| spawn a background subagent | background agents or subagents where the plan and version offer them |
| in its own worktree | `git worktree add` by hand, or the parallel-agent worktree feature where present |
| ask the user | a plain message with options |
| keep a todo list | the agent's built-in todo list (`todo_write`) |
| schedule a wake-up | none; fallback below |
| run headless | `cursor-agent -p "<prompt>"` where the CLI is installed |
| run a shell command | the terminal tool |

## Gemini CLI (documented, best effort)

| Capability | Tool or command |
|---|---|
| spawn a background subagent | subagents where enabled; otherwise run headless in a second shell |
| in its own worktree | `git worktree add` by hand |
| ask the user | a plain message with options |
| keep a todo list | `write_todos` |
| schedule a wake-up | none; fallback below |
| run headless | `gemini -p "<prompt>"` |
| run a shell command | `run_shell_command` |

## OpenCode (documented, best effort)

| Capability | Tool or command |
|---|---|
| spawn a background subagent | the `task` tool with a subagent |
| in its own worktree | `git worktree add` by hand |
| ask the user | a plain message with options |
| keep a todo list | `todowrite` |
| schedule a wake-up | none; fallback below |
| run headless | `opencode run "<prompt>"` |
| run a shell command | `bash` |

## Pi (documented, best effort)

| Capability | Tool or command |
|---|---|
| spawn a background subagent | none in the base install (extensions may add one); fallback below |
| in its own worktree | `git worktree add` by hand |
| ask the user | a plain message with options |
| keep a todo list | none built in; fallback below |
| schedule a wake-up | none; fallback below |
| run headless | `pi -p "<prompt>"` |
| run a shell command | `bash` |

## Fallbacks

- **No background subagents:** run the pieces inline, one after another, and say so in the route line's
  downgrade sentence. Where the harness has a headless mode, a piece may run headless in its own
  worktree instead, with stdin closed and a timeout.
- **No worktree isolation:** create one with `git worktree add` and give the worker its path. Never let
  two workers share one worktree.
- **No option picker:** write the question with numbered options and a recommendation, then stop.
- **No todo tool:** keep the list as a numbered checklist in your replies, updated as steps finish.
- **No wake-up:** finish at a clean checkpoint, write the handoff (see the `pause` playbook), and tell
  the human what to run or say to resume. Never fill the gap with a polling loop.
- **Headless runs** always close stdin, use the harness's non-interactive flags, and carry a timeout, so
  a prompt for input cannot stall them.
