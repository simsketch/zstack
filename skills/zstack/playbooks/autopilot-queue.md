# autopilot-queue

**Use when:** there is a queue of independent tickets to run through to merged while the human is away,
or the work will run for hours or days. With `zstack-fleet` and the VIP orchestrator installed, a large
queue across repos or accounts goes to a fleet wave instead.

## Inputs

- The ticket list, with a definition of done for each.
- `.git/zstack/config` (trust levels, base branch) and `.git/zstack/classes.conf`.
- How the human wants to be reached, and when they will next look (`notify_cmd=` in the config, if set).

## Steps

1. Print the trust table with `<zstack dir>/scripts/trust.sh` and write down, per class, whether zStack may merge (L2 or
   higher) or only open PRs.
2. For each ticket, confirm nobody owns it: search open PRs, remote branches and local worktrees for the
   ticket key. Any hit means it is owned; skip it and note why.
3. Predict the files each ticket will touch and classify them (`<zstack dir>/scripts/classify.sh --files <list>`).
   Tickets whose predicted files overlap go in the same lane or run in sequence. Solo-class tickets run
   alone and open with `hold`.
4. Give each ticket one owner: spawn a background subagent in its own worktree with a brief from
   `<zstack dir>/templates/worker-brief.md`, naming the playbook that fits the ticket (`feature`, `debug`, `refactor`
   and so on) and the principles in force. Hot files (lockfiles, CI workflows, migration indexes, route
   registries) are leased to one worker at a time.
5. Start at most three workers at a time, and add more only while the machine stays responsive.
6. Count a worker as alive only when it produced output (a report, a commit or a file change) in the last
   10 minutes. Nudge it at 30 minutes of silence; at 60, stop it by its captured pid and start a fresh worker
   in the same worktree.
7. Questions that need the human go to `.git/zstack/decisions.md` as in `human-busy`; workers move to
   work that does not need the answer.
8. When a worker reports a PR open, have a second agent (a different worker from the author) run `review`
   on it at its head sha.
9. Run `land` for each PR that passed review, one merge at a time, oldest first. Merge only where
   `<zstack dir>/scripts/trust.sh --gate <class>` passes; everything else waits for the human with its evidence.
10. After each merge, list PRs that went behind or conflicting and send them through `babysit-pr`, oldest
    first, one rebase each.
11. Schedule a wake-up between rounds instead of waiting on workers or watching CI.
12. When the queue is empty or every remaining ticket waits on the human, write a summary: merged (with
    merge shas), open and waiting (with why), blocked on decisions, follow-ups by class.

## Done when

Every ticket is merged, open and waiting for the human with its evidence, or blocked on a named decision;
each merged PR passed a second-agent `review` at its head sha and the trust gate for its class; and the
summary is written.

## Principles

- [`one-owner-per-file`](../references/principles/one-owner-per-file.md): one owner per ticket and per hot
  file.
- [`count-the-living`](../references/principles/count-the-living.md): workers count only with recent output.
- [`stop-by-pid`](../references/principles/stop-by-pid.md): a stuck worker is stopped by its captured pid.
- [`rebase-once-late`](../references/principles/rebase-once-late.md): behind PRs rebase once, oldest first,
  after each merge.
- [`spend-attention-carefully`](../references/principles/spend-attention-carefully.md): questions batch on
  the decision page.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): merges stay inside the
  trust ladder and the recorded checks.

## Preferred shape

Lane: two to six workers in parallel worktrees, one coordinator, serial merges. Fleet wave only when
`zstack-fleet` and the VIP orchestrator are both installed; without them, cap at lane and say so in the
route line. Without background subagents, run the tickets one after another in the same order.
