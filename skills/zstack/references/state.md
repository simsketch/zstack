# State files

All per-repo state lives in `.git/zstack/` (the git common dir, so every worktree of the repo sees the
same files and none of them shows in `git status`). Scripts honor `ZSTACK_STATE_DIR` to point somewhere
else, which tests use.

| Path | Written by | What it holds |
|---|---|---|
| `config` | the human (from `<zstack dir>/templates/config`) | `trust.<class>=L0..L3`, `trust.<class>.since=<ISO date>`, `sweep_repos=<path> <path>`, `notify_cmd=` (core's per-repo notifier; fleet scripts use `~/.config/zstack/config`), `base=main` |
| `classes.conf` | the human (`<zstack dir>/scripts/classify.sh --init` copies `<zstack dir>/templates/classes.conf`) | `<glob> -> <class>` and `label:<name> -> <class>` rules |
| `checks/<sha>/<name>` | `<zstack dir>/scripts/zcheck.sh` | one check run as `key=value` lines: `exit`, `tests`, `clean`, `time`, `cmd` |
| `ledger.jsonl` | `<zstack dir>/scripts/ledger.py` | one JSON object per line: `ts`, `event` (`merge`, `revert`, `bug`), pr, sha, class, checks |
| `sweeps/<date>-<class>.md` | `bug-class-sweep` (from `<zstack dir>/templates/sweep-report.md`) | the class, its search pattern, the hit table, fixes, tickets, guardrail and why-missed note |
| `decisions.md` | `human-busy` and any batched questions (from `<zstack dir>/templates/decision-page.md`) | one entry per question: options, recommendation, what is blocked, default-by time, status |
| `smoke.md` | the human (from `<zstack dir>/templates/smoke.md`) | the fixed smoke list appended to every manual-test checklist |
| `checklists/checklist-<YYYY-MM-DD>.md` | `<zstack dir>/scripts/checklist.py generate` | the day's manual-test checklist with result fields |
| `checklists/checklist-<YYYY-MM-DD>.md.posted` | `<zstack dir>/scripts/checklist.py record` | one hash per comment already posted, so a rerun skips it |
| `checklists/history.jsonl` | `<zstack dir>/scripts/checklist.py generate` | items per checklist, used to spot candidate journey tests |
| `board.md` | any worker whose approach failed | one `FAIL` line per dead end: what was tried, why it failed, the commit or log that shows it; read before starting a ticket |
| `handoffs/<branch>.md` | `pause` (from `<zstack dir>/templates/handoff.md`) | where the work stands, what is next, open questions; read by `pickup` |
| `specs/<ticket>.md` | `spec-pass` | the testable definition of done, answered questions with sources, proposed answers and the edge cases decided for an open ticket |
| `edge-cases.md` | `bug-class-sweep`, or the human | repo-specific edge-case classes, numbered on from `<zstack dir>/references/edge-cases.md`; every PR answers them too |
| `playbooks/<name>.md` | the router, step 2 | one-off playbooks written for goals the catalog does not cover |

Nothing in `.git/zstack/` holds secrets, and nothing there is pushed. A fresh clone starts empty; carry the
track record across with `<zstack dir>/scripts/ledger.py export` and `import`, and copy `config` and `classes.conf` by
hand.

Per machine, only zstack-fleet writes state: `~/.config/zstack/` (overridable with `ZSTACK_CONFIG_DIR`)
and `~/.local/share/zstack/<project>/` (overridable with `ZSTACK_DATA_DIR`). While it runs, core zStack
writes nothing outside the repo; only its `install.sh` writes outside it, as symlinks under
`~/.agents/skills/` and `~/.claude/skills/`.
