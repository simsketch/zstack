# pause

**Use when:** work has to stop cleanly: the session is ending, context is getting large, the human wants to
switch tasks, or a worker is being replaced. Another agent should be able to resume from disk alone.

## Inputs

- The current branch and worktree.
- The route line, the playbook, its todo list with what is done, and the principles in force.
- Any processes this session started (dev servers, watchers, test runs) and their pids.

## Steps

1. Stop starting new steps. Finish or back out the edit in progress so the code is in a state you can
   describe in one sentence.
2. Stop the processes you started, each by its captured pid or by a path inside this worktree. Leave
   everything else running.
3. Fill `<zstack dir>/templates/handoff.md` and save it to `.git/zstack/handoffs/<branch>.md`, creating
   parent directories first (a branch like `feat/x` nests one level). Cover goal and done, route line,
   todo list with status, what is in progress, decisions taken and their sources, open questions,
   commands to rerun, and known traps.
4. Commit or delete every changed and untracked path, using a WIP commit: stage by path, check
   `git diff --cached --stat`, and commit with subject `wip: <one-line state>` and the handoff text as the
   commit body. Use a commit instead of `git stash`, which is shared across worktrees.
5. On the now clean tree, record the checks you rely on at the WIP commit:
   `<zstack dir>/scripts/zcheck.sh --name <check> -- <command>`. Add the results to the handoff file.
6. If the repo's rules allow pushing work branches, push the branch so the work survives this machine.
7. Confirm nothing is left only in the working tree: `git status --porcelain` prints nothing, and
   `git log -1` shows the WIP commit.
8. Reply with the branch, the WIP commit sha, the handoff path, and the single next step.

## Done when

`git status --porcelain` prints nothing, the WIP commit exists with the handoff in its body, the handoff
file is saved under `.git/zstack/handoffs/`, and every process this session started has stopped.

## Principles

- [`stop-by-pid`](../references/principles/stop-by-pid.md): processes stop by captured pid or a path in
  this worktree.
- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): the WIP commit can
  be amended or reverted by whoever resumes.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): the handoff states
  which checks were recorded, at which sha, and leaves the rest as unverified.
- [`name-what-changed`](../references/principles/name-what-changed.md): the handoff lists the principles in
  force and what each decided so far.

## Preferred shape

Inline: the session that holds the context writes the handoff.
