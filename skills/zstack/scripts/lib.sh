#!/usr/bin/env bash
# lib.sh: shared helpers for the zstack bash scripts. Source it; it defines
# functions only and changes no shell options.
#
#   zs_die <prog> <message...>   print "<prog>: <message>" on stderr, exit 1
#   zs_state_dir                 print the per-repo state dir: $ZSTACK_STATE_DIR,
#                                else <git common dir>/zstack (absolute)
#   zs_gh <args...>              run gh as ${ZSTACK_GH:-gh}
#   zs_config_get <key> [file]   print the value of key=value from the state
#                                config (default $(zs_state_dir)/config)

zs_die() {
  local prog="$1"; shift
  printf '%s: %s\n' "$prog" "$*" >&2
  exit 1
}

zs_state_dir() {
  if [ -n "${ZSTACK_STATE_DIR:-}" ]; then
    printf '%s\n' "$ZSTACK_STATE_DIR"
    return 0
  fi
  local common
  common="$(git rev-parse --git-common-dir 2>/dev/null)" || {
    echo "not inside a git repository (set ZSTACK_STATE_DIR to use another state dir)" >&2
    return 1
  }
  common="$(cd "$common" && pwd -P)" || return 1
  printf '%s/zstack\n' "$common"
}

zs_gh() {
  "${ZSTACK_GH:-gh}" "$@"
}

zs_config_get() {
  local key="$1" file="${2:-}"
  if [ -z "$file" ]; then
    file="$(zs_state_dir)/config" || return 1
  fi
  [ -f "$file" ] || return 1
  local line k
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    k="${line%%=*}"
    k="$(printf '%s' "$k" | tr -d '[:space:]')"
    if [ "$k" = "$key" ]; then
      printf '%s\n' "${line#*=}"
      return 0
    fi
  done < "$file"
  return 1
}
