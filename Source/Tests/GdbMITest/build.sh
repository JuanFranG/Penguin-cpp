#!/bin/sh
# Builds and runs the GDB/MI reader test with Free Pascal (no Lazarus or gdb
# needed).
# usage: Source/Tests/GdbMITest/build.sh [--run]
#   FPCFLAGS="-Cr -Co -Ct -CR -Sa -gh -gl" adds runtime checks and leak reports
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

fpc -vewn $FPCFLAGS -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/gdbmitest.lpr"

if [ "$1" = "--run" ]; then
  "$OUT/gdbmitest"
fi
