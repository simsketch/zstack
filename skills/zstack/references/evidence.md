# Evidence, gates and the trust ladder

## The three evidence words

Report these separately, each with its own proof. A missing one is written "not yet" with the next step.

| Word | Means | Proof |
|---|---|---|
| implemented | merged | the merge sha |
| deployed | running in a named environment | the serving artifact contains the commit, for example `git merge-base --is-ancestor <merge-sha> <deployed-sha>` exits 0 |
| verified | someone checked the behavior there | who checked, in which environment, and when |

"Shipped" and "live" may be written only with the deployed proof in hand. "Fixed" needs the reproduction
passing at a named commit, and "passing" needs a recorded check at the head sha.

## The four gates

1. **Checks recorded at the head commit.** A check counts only when it ran on a clean tree (no
   uncommitted or untracked files) at the PR head. Record each with
   `<zstack dir>/scripts/zcheck.sh --name <name> -- <cmd...>`; it writes `.git/zstack/checks/<sha>/<name>` with the
   exit code, test count, clean flag, time and command. Zero tests fails (exit 3); use `--no-count` for
   lint and typecheck and `--min-tests <n>` to require more. Before merging, run
   `<zstack dir>/scripts/zcheck.sh --verify <sha> <name>...`, which exits 0 only when every named check exists, passed,
   was clean and did not run zero tests. `<zstack dir>/scripts/zcheck.sh --list [<sha>]` shows what is recorded.
2. **Merge pinned to the verified head.** `gh pr merge <n> --match-head-commit <sha>`, with the same sha
   you verified, so a late push cannot slip in.
3. **One merge at a time per repo.** Finish one merge, including the post-merge check on main, before
   starting the next.
4. **Hold for sensitive classes.** Solo-class PRs open with a `hold` label, as drafts while the class is
   at L0 (the default for solo). A push after review needs a
   delta review of just that push before the hold comes off. Workers never remove `hold`; the human or
   the reviewer of record does.

## PR classes

Classes, from least to most risky: `docs` < `tests` < `small-ui` < `feature` < `solo`.

- The human decides classes through rules in `.git/zstack/classes.conf`, one per line:
  `<glob> -> <class>` or `label:<name> -> <class>`. Start it with `<zstack dir>/scripts/classify.sh --init`.
- `<zstack dir>/scripts/classify.sh` computes a PR's class from its changed files (`--pr <n>`, `--base <ref>` or
  `--files <file>`). The riskiest class of any file wins, and a file no rule matches counts as
  `feature`.
- `--claimed <class>` records the class you think it is; the result is never lower than the computed
  one. You may raise a class by hand and never lower it.
- The merge gate reruns `classify.sh` at the head commit, so a later push that touches a riskier path
  moves the PR up before it can merge.
- The shipped solo defaults (migrations, workflows, infra, auth, security, payments, billing, and the
  `security` and `hold` labels) sit under a `# zstack defaults: keep` header. Add rules freely; removing
  a default means editing the file by hand, on purpose.

## The trust ladder

Per repo and per class, the ladder sets how much zStack may do without the human.

| Level | zStack may | Earned by |
|---|---|---|
| L0 draft only | open only a draft PR labelled `hold`; never mark it ready, remove `hold` or merge; the human takes it over | starting point for solo classes |
| L1 open | open ready PRs with the evidence packet; the human merges | starting point for every other class |
| L2 merge on evidence | merge its own PRs that pass all four gates, one at a time | the human sets it for a class after a track record |
| L3 batch | assemble and merge area batches | L2 for the class, plus zstack-fleet installed |

Rules:

- Only the human raises a level, by writing `trust.<class>=L<n>` in `.git/zstack/config` (optionally
  `trust.<class>.since=<ISO date>`).
- A revert in a class drops it one level automatically, until the human restores it by updating
  `trust.<class>.since`.
- Solo classes never go above L1. L3 needs zstack-fleet; without it the effective level caps at L2.
- Read a class's effective level from the `effective` column of `<zstack dir>/scripts/trust.sh --class <class>`.
  At L0, `land` opens the PR as a draft with `hold` and stops there.

## Track record

- After each merge, record it: `<zstack dir>/scripts/ledger.py add --pr <n> --sha <sha> --class <class> --checks a,b`.
- When a merge is later reverted or traced as a bug's cause:
  `<zstack dir>/scripts/ledger.py flag --sha <sha> --reverted` or `--bug <ref>`.
- `<zstack dir>/scripts/ledger.py stats [--json]` summarizes; `export <file>` and `import <file>` move the record to a
  fresh clone or another machine.
- `<zstack dir>/scripts/trust.sh` prints per class: merges, revert rate, bug rate, configured, effective and suggested
  level. The suggestion is advice only. `<zstack dir>/scripts/trust.sh --gate <class>` exits 0 when the effective
  level is L2 or higher; run it before any merge you make yourself. `--gate <class> --level L3` exits 0
  only at L3, which every class in a batch needs.
