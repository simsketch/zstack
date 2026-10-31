#!/usr/bin/env bash
# Session-start routing hint for Claude Code, Codex and Gemini CLI.
# Prints two lines and exits 0. Reads no files and takes no action.
# Argument (optional): the harness name; accepted for logging symmetry only.
cat <<'HINT'
zStack is installed. For multi-file changes, design choices, bugs with an unknown cause, performance work, or any request to run work in parallel, start with the zstack skill.
It picks a playbook, names the principles it applies, and reports what each one changed.
HINT
exit 0
