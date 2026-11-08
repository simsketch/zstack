#!/usr/bin/env bash
# Tests for scripts/check-manifests.sh on the real tree and on broken copies.
# shellcheck source=tests/helpers.sh
. "$(dirname "$0")/helpers.sh"
CHECK="$ZT_ROOT/scripts/check-manifests.sh"
export ZSTACK_VALIDATOR=stdlib

OUT="$(bash "$CHECK" "$ZT_ROOT" 2>&1)"; RC=$?
assert_eq 0 "$RC" "real tree passes"

copy_tree() {
  local d; d="$(zt_tmpdir)"
  (cd "$ZT_ROOT" && tar cf - --exclude .git .) | (cd "$d" && tar xf -)
  printf '%s' "$d"
}

d="$(copy_tree)"
sed -E 's/"version": "[0-9.]+"/"version": "9.9.9"/' "$d/gemini-extension.json" > "$d/x" && mv "$d/x" "$d/gemini-extension.json"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "version mismatch fails"
assert_contains "$OUT" "gemini-extension.json" "mismatch names the manifest"

d="$(copy_tree)"
printf '{ not json' > "$d/.codex-plugin/plugin.json"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "bad JSON fails"

d="$(copy_tree)"
sed 's#"./skills/zstack"#"./skills/missing"#' "$d/package.json" > "$d/x" && mv "$d/x" "$d/package.json"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "missing skill dir in pi block fails"

d="$(copy_tree)"
sed 's/^name: zstack$/name: other/' "$d/skills/zstack/SKILL.md" > "$d/x" && mv "$d/x" "$d/skills/zstack/SKILL.md"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "skill name differing from folder fails"

# Playbook catalog check
d="$(copy_tree)"
rm -rf "$d/skills/zstack/playbooks"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 0 "$RC" "no playbooks dir passes"
assert_contains "$OUT" "skip: playbook" "no playbooks dir is reported as skipped"

mkdir -p "$d/skills/zstack/playbooks"
printf '# debug\n' > "$d/skills/zstack/playbooks/debug.md"
printf '# land\n' > "$d/skills/zstack/playbooks/land.md"
# A self-contained SKILL.md whose catalog lists exactly the two fixture
# playbooks, so the test does not depend on the real 16-playbook catalog.
ver="$(sed -n 's/^  version: "\(.*\)"$/\1/p' "$ZT_ROOT/skills/zstack/SKILL.md")"
cat > "$d/skills/zstack/SKILL.md" <<'MD'
---
name: zstack
description: Fixture router used by the playbook catalog test.
license: MIT
metadata:
  version: "@VER@"
---

# zStack fixture

## Playbook catalog

| Playbook | Use when |
|---|---|
| `debug` | a bug with an unknown cause |
| `land` | a reviewed PR is ready to merge |

## Principle index

- `reproduce-first`: see it fail before fixing it
MD
sed "s/@VER@/$ver/" "$d/skills/zstack/SKILL.md" > "$d/x" && mv "$d/x" "$d/skills/zstack/SKILL.md"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 0 "$RC" "catalog matching playbooks passes"

printf '# perf\n' > "$d/skills/zstack/playbooks/perf.md"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "playbook file missing from SKILL.md fails"
assert_contains "$OUT" "perf" "unlisted playbook is named"
rm "$d/skills/zstack/playbooks/perf.md"

rm "$d/skills/zstack/playbooks/land.md"
OUT="$(bash "$CHECK" "$d" 2>&1)"; RC=$?
assert_eq 1 "$RC" "catalog entry with no file fails"
assert_contains "$OUT" "land" "missing playbook file is named"

# Every shipped playbook keeps the seven-part shape, in order.
for f in "$ZT_ROOT"/skills/zstack/playbooks/*.md; do
  [ -f "$f" ] || continue
  n="$(basename "$f" .md)"
  got="$(grep -E '^(# |\*\*Use when:\*\*|## (Inputs|Steps|Done when|Principles|Preferred shape)$)' "$f" \
    | sed -E 's/^\*\*Use when:\*\*.*/Use when/' | tr '\n' '|')"
  assert_eq "# $n|Use when|## Inputs|## Steps|## Done when|## Principles|## Preferred shape|" "$got" \
    "playbook $n has the seven parts in order"
done

finish
