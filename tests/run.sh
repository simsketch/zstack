#!/usr/bin/env bash
# Runs every tests/test_*.sh and prints ALL PASS when each one exits 0.
set -u
here="$(cd "$(dirname "$0")" && pwd -P)"
failed=0
for t in "$here"/test_*.sh; do
  [ -f "$t" ] || continue
  printf '%s\n' "$(basename "$t")"
  if ! bash "$t"; then
    failed=$((failed + 1))
  fi
done
if [ "$failed" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "FAILED: $failed test file(s)"
  exit 1
fi
