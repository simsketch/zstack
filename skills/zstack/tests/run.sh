#!/usr/bin/env bash
# Runs every test_*.sh next to this file. Prints ALL PASS when each one exits 0,
# else SOME TESTS FAILED (and exits 1).
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
  echo "SOME TESTS FAILED ($failed file(s))"
  exit 1
fi
