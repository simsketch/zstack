# State files

All per-repo state lives in `.git/zstack/` (the git common dir, so every worktree of the repo sees the
same files and none of them shows in `git status`). Scripts honor `ZSTACK_STATE_DIR` to point somewhere
else, which tests use.

| Path | Written by | What it holds |
|---|---|---|
| `config` | the human (from `templates/config`) | `trust.<class>=L0..L3`, `trust.<class>.since=<ISO date>`, `sweep_repos=<path> <path>`, `notify_cmd=`, `base=main` |
| `classes.conf` | the human (`scripts/classify.sh --init` copies `templates/classes.conf`) | `<glob> -> <class>` and `label:<name> -> <class>` rules |
| `checks/<sha>/<name>` | `scripts/zcheck.sh` | one check run as `key=value` lines: `exit`, `tests`, `clean`, `time`, `cmd` |
| `ledger.jsonl` | `scripts/ledger.py` | one JSON object per line: `ts`, `event` (`merge`, `revert`, `bug`), pr, sha, class, checks |
| `sweeps/<date>-<class>.md` | `bug-class-sweep` (from `templates/sweep-report.md`) | the class, its search pattern, the hit table, fixes, tickets, guardrail and why-missed note |
| `decisions.md` | `human-busy` and any batched questions (from `templates/decision-page.md`) | one entry per question: options, recommendation, what is blocked, default-by time, status |
| `smoke.md` | the human (from `templates/smoke.md`) | the fixed smoke list appended to every manual-test checklist |
| `checklists/checklist-<YYYY-MM-DD>.md` | `scripts/checklist.py generate` | the day's manual-test checklist with result fields |
| `checklists/history.jsonl` | `scripts/checklist.py generate` | items per checklist, used to spot candidate journey tests |
| `handoffs/<branch>.md` | `pause` (from `templates/handoff.md`) | where the work stands, what is next, open questions; read by `pickup` |
| `playbooks/<name>.md` | the router, step 2 | one-off playbooks written for goals the catalog does not cover |

Nothing in `.git/zstack/` holds secrets, and nothing there is pushed. A fresh clone starts empty; carry the
track record across with `scripts/ledger.py export` and `import`, and copy `config` and `classes.conf` by
hand.

Per machine, only zstack-fleet writes state: `~/.config/zstack/` (overridable with `ZSTACK_CONFIG_DIR`)
and `~/.local/share/zstack/<project>/` (overridable with `ZSTACK_DATA_DIR`). Core zStack writes nothing
outside the repo.
