#!/usr/bin/env bash
# setup-demo.sh <dir>
#
# Builds the fictional `acme-notes` repo in <dir> (which must not exist or be
# empty). It is a tiny Python CLI used by the zStack trigger tests and for
# trying zStack by hand:
#
#   - notes live in a JSON file (notes.json, or $ACME_NOTES_FILE)
#   - `export` writes CSV and drops the last row (off-by-one)
#   - `list --limit N` shows N-1 notes (the same off-by-one, a sibling)
#   - the README has a typo
#   - tests use unittest and pass despite both bugs
#   - branch feature/tags: a small diff that adds tags to `add`
#   - branch wip/search: a half-done `search` command, a WIP commit and a
#     handoff file at .git/zstack/handoffs/wip/search.md
#
# Needs bash, git and Python 3. Touches nothing outside <dir>.
set -eu

[ $# -eq 1 ] || { echo "usage: setup-demo.sh <dir>" >&2; exit 2; }
dir="$1"
if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
  echo "setup-demo.sh: $dir exists and is not empty" >&2
  exit 2
fi
mkdir -p "$dir"
cd "$dir"

export GIT_AUTHOR_NAME="Acme Dev" GIT_AUTHOR_EMAIL="dev@example.com"
export GIT_COMMITTER_NAME="Acme Dev" GIT_COMMITTER_EMAIL="dev@example.com"
git init -q -b main
git config user.name "Acme Dev"
git config user.email "dev@example.com"
git config commit.gpgsign false

mkdir -p acme_notes tests

cat > README.md <<'EOF'
# acme-notes

Acme Notes is a tiny comand-line notes app. Notes are stored in a JSON file.

## Usage

```
python3 -m acme_notes add "Buy milk"
python3 -m acme_notes list --limit 5
python3 -m acme_notes export notes.csv
```

Set `ACME_NOTES_FILE` to keep notes somewhere other than `./notes.json`.

## Tests

```
python3 -m unittest discover -s tests
```
EOF

cat > .gitignore <<'EOF'
__pycache__/
notes.json
*.csv
EOF

cat > acme_notes/__init__.py <<'EOF'
"""Acme Notes: a tiny command-line notes app."""
__version__ = "0.3.0"
EOF

cat > acme_notes/__main__.py <<'EOF'
from acme_notes.cli import main

raise SystemExit(main())
EOF

cat > acme_notes/store.py <<'EOF'
"""Load and save notes in a JSON file."""
import json
import os
import time


def notes_path():
    return os.environ.get("ACME_NOTES_FILE", "notes.json")


def load(path=None):
    path = path or notes_path()
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save(notes, path=None):
    path = path or notes_path()
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(notes, fh, indent=2)


def add(text, path=None):
    notes = load(path)
    note = {"id": len(notes) + 1, "text": text, "created": int(time.time())}
    notes.append(note)
    save(notes, path)
    return note
EOF

cat > acme_notes/export.py <<'EOF'
"""Export notes to CSV."""
import csv

FIELDS = ["id", "text", "created"]


def to_csv(notes, fh):
    writer = csv.writer(fh)
    writer.writerow(FIELDS)
    for i in range(len(notes) - 1):
        note = notes[i]
        writer.writerow([note.get(f, "") for f in FIELDS])
EOF

cat > acme_notes/cli.py <<'EOF'
"""Command-line entry point."""
import argparse
import sys

from acme_notes import export, store


def cmd_add(args):
    note = store.add(args.text)
    print("added #%d" % note["id"])
    return 0


def cmd_list(args):
    notes = store.load()
    if args.limit:
        notes = notes[: args.limit - 1]
    for note in notes:
        print("#%d %s" % (note["id"], note["text"]))
    return 0


def cmd_export(args):
    notes = store.load()
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        export.to_csv(notes, fh)
    print("exported to %s" % args.out)
    return 0


def build_parser():
    p = argparse.ArgumentParser(prog="acme-notes")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add", help="add a note")
    a.add_argument("text")
    a.set_defaults(func=cmd_add)
    ls = sub.add_parser("list", help="list notes")
    ls.add_argument("--limit", type=int, default=0)
    ls.set_defaults(func=cmd_list)
    ex = sub.add_parser("export", help="export notes to CSV")
    ex.add_argument("out")
    ex.set_defaults(func=cmd_export)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
EOF

cat > tests/__init__.py <<'EOF'
EOF

cat > tests/test_store.py <<'EOF'
import os
import tempfile
import unittest

from acme_notes import store


class StoreTest(unittest.TestCase):
    def test_add_then_load(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "notes.json")
            store.add("first", path)
            store.add("second", path)
            notes = store.load(path)
            self.assertEqual([n["text"] for n in notes], ["first", "second"])
            self.assertEqual([n["id"] for n in notes], [1, 2])

    def test_missing_file_is_empty(self):
        self.assertEqual(store.load("/nonexistent/notes.json"), [])


if __name__ == "__main__":
    unittest.main()
EOF

cat > tests/test_export.py <<'EOF'
import io
import unittest

from acme_notes import export


class ExportTest(unittest.TestCase):
    def test_header(self):
        buf = io.StringIO()
        export.to_csv([], buf)
        self.assertEqual(buf.getvalue().splitlines(), ["id,text,created"])


if __name__ == "__main__":
    unittest.main()
EOF

git add -A
git commit -q -m "acme-notes: add, list and CSV export"

# Branch feature/tags: a small reviewable diff.
git checkout -q -b feature/tags
python3 - <<'EOF'
import re
p = "acme_notes/store.py"
s = open(p).read()
s = s.replace("def add(text, path=None):", "def add(text, path=None, tags=None):")
s = s.replace('"created": int(time.time())}', '"created": int(time.time()), "tags": tags or []}')
open(p, "w").write(s)
p = "acme_notes/cli.py"
s = open(p).read()
s = s.replace("note = store.add(args.text)", "note = store.add(args.text, tags=args.tag)")
s = s.replace('    a.add_argument("text")\n',
              '    a.add_argument("text")\n    a.add_argument("--tag", action="append", help="tag the note (repeatable)")\n')
open(p, "w").write(s)
EOF
git add -A
git commit -q -m "feat: tag notes with --tag on add"
git checkout -q main

# Branch wip/search: half-done work left by another agent, with a handoff.
git checkout -q -b wip/search
cat > acme_notes/search.py <<'EOF'
"""Search notes by text. Work in progress."""


def search(notes, query):
    query = query.lower()
    # TODO: match tags too once feature/tags lands
    # TODO: rank by how recent the note is
    return [n for n in notes if query in n["text"]]
EOF
git add -A
git commit -q -m "wip: search module started, not wired into the CLI

See .git/zstack/handoffs/wip/search.md for where this stands."
head_sha="$(git rev-parse HEAD)"
mkdir -p .git/zstack/handoffs/wip
cat > .git/zstack/handoffs/wip/search.md <<EOF
# Handoff: wip/search

Saved to: .git/zstack/handoffs/wip/search.md
Written: 2026-10-28 18:40 UTC by worker-2
Worktree: main checkout
Head: ${head_sha}
PR: none yet  Ticket: NOTES-12

## Goal and done

Goal: add \`acme-notes search <query>\` that prints matching notes.
Done when: the command works case-insensitively, has unittest coverage, and a PR is open.

## Route

Route: feature -> land, shape: inline, principles: data-shape-first, smallest-reversible-change

## Todo list

1. [x] Name the data shape: a search returns a list of note dicts, same shape as store.load()
2. [ ] Write the search function (in progress: matching is case-sensitive on the note side)
3. [ ] Wire a \`search\` subcommand into cli.py
4. [ ] Add tests/test_search.py
5. [ ] Open the PR with the evidence packet

## Checks recorded

- none yet

## Decisions so far

- Search matches note text only for now; tags wait for feature/tags (source: NOTES-12 comment)

## Open questions

- Should results be ranked by recency? (on the decision page: no)

## Commands to rerun

\`\`\`
python3 -m unittest discover -s tests
\`\`\`

## Traps

- \`query.lower()\` is applied but the note text is not lowered, so "Milk" misses "milk".

## Next step

Lower the note text in search(), then wire the subcommand.
EOF
git checkout -q main

echo "acme-notes ready at $(pwd -P)"
echo "branches: $(git branch --format='%(refname:short)' | tr '\n' ' ')"
