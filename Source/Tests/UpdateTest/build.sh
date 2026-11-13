#!/bin/sh
# Builds and runs update lookup tests with Free Pascal (no Lazarus needed).
# usage: Source/Tests/UpdateTest/build.sh [--run]
# FPCFLAGS adds compiler/runtime checks.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

fpc -vewn $FPCFLAGS -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/updatetest.lpr"

if [ "${1:-}" = "--run" ]; then
  "$OUT/updatetest"
fi
