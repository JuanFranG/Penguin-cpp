#!/bin/sh
# Builds and runs the lldb-dap engine test with Free Pascal (no Lazarus
# needed). It needs lldb-dap and clang (macOS); without them it is skipped.
# usage: Source/Tests/DapEngineTest/build.sh [--run]
#   FPCFLAGS="-Cr -Co -Ct -CR -Sa -gh -gl" adds runtime checks and leak reports
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

fpc -vewn $FPCFLAGS -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/dapenginetest.lpr"

if [ "$1" = "--run" ]; then
  "$OUT/dapenginetest"
fi
