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
   higher), only open PRs (L1), or only open a draft labelled `hold` for the human to take over (L0).
2. For each ticket, confirm nobody owns it: search open PRs, remote branches and local worktrees for the
   ticket key. Any hit means it is owned; skip it and note why.
3. Triage each remaining ticket as clear or open (the test is in `spec-pass` step 1). Open tickets get a
   `spec-pass` first, as cheap read-only subagents a few at a time, with their questions batched onto
   `.git/zstack/decisions.md`. An open ticket gets a worker only once its spec is written and no protected
   question is still open; clear tickets go ahead meanwhile.
4. Predict the files each ticket will touch and classify them (`<zstack dir>/scripts/classify.sh --files <list>`).
   Tickets whose predicted files overlap go in the same lane or run in sequence. Solo-class tickets run
   alone and open with `hold`; at L0 (the solo default) as a draft that the human takes over.
5. Give each ticket one owner: spawn a background subagent in its own worktree with a brief from
   `<zstack dir>/templates/worker-brief.md`, naming the playbook that fits the ticket (`feature`, `debug`, `refactor`
   and so on), the spec path from step 3, and the principles in force. Hot files (lockfiles, CI workflows, migration indexes, route
   registries) are leased to one worker at a time.
6. Start at most three workers in any two minutes, wait for each batch to report before starting the
   next, and add more only while the machine stays responsive. Tell every worker to read `.git/zstack/board.md` before it starts and to append a one-line
   `FAIL` entry (what was tried, why it failed, commit or log) whenever an approach fails, so the others
   skip that dead end.
7. Count a worker as alive only when it produced output (a report, a commit or a file change) in the last
   10 minutes. Nudge it at 30 minutes of silence; at 60, stop it by its captured pid and start a fresh worker
   in the same worktree. Its claim on the ticket and its leased files expires at the same point, so
   another worker may take them over.
8. Questions that need the human go to `.git/zstack/decisions.md` as in `human-busy`; workers move to
   work that does not need the answer.
9. When a worker reports a PR open, have a second agent (a different worker from the author) run `review`
   on it at its head sha.
10. Run `land` for each PR that passed review, one merge at a time, oldest first. Merge only where
   `<zstack dir>/scripts/trust.sh --gate <class>` passes; everything else waits for the human with its evidence.
11. After each merge, list PRs that went behind or conflicting and send them through `babysit-pr`, oldest
    first, one rebase each.
12. Schedule a wake-up between rounds instead of waiting on workers or watching CI.
13. When the queue is empty or every remaining ticket waits on the human, write a summary: merged (with
    merge shas), open and waiting (with why), blocked on decisions, follow-ups by class.

## Done when

Every ticket is merged, open and waiting for the human with its evidence, or blocked on a named decision
(open tickets included, with their spec);
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
- [`list-your-assumptions`](../references/principles/list-your-assumptions.md): open tickets are specified
  before work starts, and every PR lists the choices its worker made.
- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): merges stay inside the
  trust ladder and the recorded checks.

## Preferred shape

Lane: two to six workers in parallel worktrees, one coordinator, serial merges. Fleet wave only when
`zstack-fleet` and the VIP orchestrator are both installed; without them, cap at lane and say so in the
route line. Without background subagents, run the tickets one after another in the same order.
