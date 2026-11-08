#!/usr/bin/env bash
# Tests that the skill text stays consistent: every principle the router indexes has a leaf, the
# PR body template carries the evidence sections, and the edge-case checklist is numbered 1..10.
# shellcheck source=tests/helpers.sh
. "$(dirname "$0")/helpers.sh"
SK="$ZT_ROOT/skills/zstack"

# shellcheck disable=SC2016  # backticks are literal Markdown here
idx="$(sed -n '/^## Principle index/,/^## Evidence and gates/p' "$SK/SKILL.md" | grep -oE '^- `[a-z-]+`' | sed -e 's/^- `//' -e 's/`$//')"
for p in $idx; do
  check "principle $p has a leaf" test -f "$SK/references/principles/$p.md"
done
for f in "$SK"/references/principles/*.md; do
  n="$(basename "$f" .md)"
  assert_contains "$idx" "$n" "leaf $n is in the principle index"
done

body="$(cat "$SK/templates/pr-body.md")"
for s in "## Route" "## Principles" "## Evidence" "## How to test" "## Assumptions" "## Edge cases" "## Drive-bys" "## Follow-ups"; do
  assert_contains "$body" "$s" "pr-body has $s"
done

classes="$(grep -cE '^[0-9]+\. \*\*' "$SK/references/edge-cases.md")"
assert_eq 10 "$classes" "edge-case checklist has ten classes"
tmpl="$(sed -n '/^## Edge cases/,/^## Drive-bys/p' "$SK/templates/pr-body.md" | grep -cE '^[0-9]+\. ')"
assert_eq "$classes" "$tmpl" "pr-body answers every edge-case class"

brief="$(cat "$SK/templates/worker-brief.md")"
assert_contains "$brief" "## Assumptions" "worker brief asks for assumptions"
assert_contains "$brief" "references/edge-cases.md" "worker brief points at the edge-case checklist"

no_long_dashes() { ! LC_ALL=C grep -rn $'\xe2\x80\x93\|\xe2\x80\x94' "$SK/SKILL.md" "$SK/references" "$SK/playbooks" "$SK/templates" "$ZT_ROOT/README.md" "$ZT_ROOT/NOTICE"; }
check "no em or en dashes in the skill text" no_long_dashes

finish
