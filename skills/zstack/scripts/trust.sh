#!/usr/bin/env bash
# trust.sh: per-class trust levels for this repo.
#
#   trust.sh [--class <c>] [--gate <c> [--level L2|L3]]
#
# Prints `class merges revert% bug% configured effective suggested`. The
# suggestion is advice; only the human raises a level, in $STATE/config
# (`trust.<class>=L0|L1|L2|L3`, `trust.<class>.since=<ISO date>`).
# --gate <c> exits 0 when the class's effective level is L2 or higher (one PR
# may merge on evidence); with --level L3 it needs L3 (a batch may merge).
# The rules live in ledger.py (see its header).
set -u
here="$(cd "$(dirname "$0")" && pwd -P)"
command -v python3 >/dev/null 2>&1 || { echo "trust: python3 is required" >&2; exit 1; }
exec python3 -I "$here/ledger.py" trust "$@"
