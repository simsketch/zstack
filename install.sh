#!/usr/bin/env bash
# install.sh [--uninstall] [--dest-agents <dir>] [--dest-claude <dir>] [--no-validate]
#
# Links every skills/<name>/ folder in this repo into ~/.agents/skills/ and
# ~/.claude/skills/ as symlinks, so a `git pull` here updates every harness.
#
# - An existing symlink that already points here is left alone ("already linked").
# - A real folder or file, or a symlink pointing anywhere else, is never touched:
#   the installer refuses with exit 2 before linking anything.
# - --uninstall removes only symlinks that point into this repo.
# - After installing, runs the Agent Skills validator (agentskills, or
#   uvx --from skills-ref agentskills) when one is available. Set
#   ZSTACK_SKIP_VALIDATE=1 or pass --no-validate to skip it.
set -u

usage() {
  echo "usage: install.sh [--uninstall] [--dest-agents <dir>] [--dest-claude <dir>] [--no-validate]" >&2
  exit 2
}

here="$(cd "$(dirname "$0")" && pwd -P)"
dest_agents="${HOME}/.agents/skills"
dest_claude="${HOME}/.claude/skills"
mode=install
validate=1
[ -n "${ZSTACK_SKIP_VALIDATE:-}" ] && validate=0

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) mode=uninstall; shift ;;
    --dest-agents) [ $# -ge 2 ] || usage; dest_agents="$2"; shift 2 ;;
    --dest-claude) [ $# -ge 2 ] || usage; dest_claude="$2"; shift 2 ;;
    --no-validate) validate=0; shift ;;
    -h|--help) usage ;;
    *) echo "install.sh: unknown argument: $1" >&2; usage ;;
  esac
done

skills=()
for d in "$here"/skills/*/; do
  [ -f "${d}SKILL.md" ] || continue
  skills+=("$(basename "$d")")
done
if [ ${#skills[@]} -eq 0 ]; then
  echo "install.sh: no skills found under $here/skills" >&2
  exit 1
fi

if [ "$mode" = uninstall ]; then
  for dest in "$dest_agents" "$dest_claude"; do
    for s in "${skills[@]}"; do
      link="$dest/$s"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$here/skills/$s" ]; then
        rm "$link"
        echo "removed: $link"
      elif [ -e "$link" ] || [ -L "$link" ]; then
        echo "left alone (not ours): $link"
      fi
    done
  done
  exit 0
fi

# Preflight: refuse before changing anything.
blocked=0
for dest in "$dest_agents" "$dest_claude"; do
  for s in "${skills[@]}"; do
    link="$dest/$s"
    src="$here/skills/$s"
    if [ -L "$link" ]; then
      if [ "$(readlink "$link")" != "$src" ]; then
        echo "refusing: $link is a symlink to $(readlink "$link"), not $src" >&2
        blocked=1
      fi
    elif [ -e "$link" ]; then
      echo "refusing: $link exists and is not a symlink; move it aside and run again" >&2
      blocked=1
    fi
  done
done
[ "$blocked" -eq 0 ] || exit 2

for dest in "$dest_agents" "$dest_claude"; do
  mkdir -p "$dest" || { echo "install.sh: cannot create $dest" >&2; exit 1; }
  for s in "${skills[@]}"; do
    link="$dest/$s"
    src="$here/skills/$s"
    if [ -L "$link" ]; then
      echo "already linked: $link"
    else
      ln -s "$src" "$link" || { echo "install.sh: cannot link $link" >&2; exit 1; }
      echo "linked: $link -> $src"
    fi
  done
done

if [ "$validate" -eq 1 ]; then
  validator=()
  if command -v agentskills >/dev/null 2>&1; then
    validator=(agentskills)
  elif command -v uvx >/dev/null 2>&1; then
    validator=(uvx --from skills-ref agentskills)
  fi
  if [ ${#validator[@]} -gt 0 ]; then
    for s in "${skills[@]}"; do
      if ! "${validator[@]}" validate "$here/skills/$s"; then
        echo "install.sh: validator reported problems in skills/$s" >&2
        exit 1
      fi
    done
  else
    echo "note: no Agent Skills validator found (install skills-ref to enable); skipped"
  fi
fi

echo "done. Restart your agent session to pick up the skills."
