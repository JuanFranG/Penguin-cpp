#!/bin/sh
# Builds and runs the debugger engine test with Free Pascal (no Lazarus
# needed). The session part needs gdb and gcc; without them it is skipped.
# usage: Source/Tests/GdbEngineTest/build.sh [--run]
#   FPCFLAGS="-Cr -Co -Ct -CR -Sa -gh -gl" adds runtime checks and leak reports
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

fpc -vewn $FPCFLAGS -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/gdbenginetest.lpr"

if [ "$1" = "--run" ]; then
  "$OUT/gdbenginetest"
fi
