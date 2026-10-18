#!/bin/sh
# Builds and runs the Makefile names test with Free Pascal (no Lazarus
# needed). The project part needs make and cc.
# usage: Source/Tests/MakefileTest/build.sh [--run]
#   FPCFLAGS="-Cr -Co -Ct -CR -Sa -gh -gl" adds runtime checks and leak reports
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

fpc -vewn $FPCFLAGS -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/makefiletest.lpr"

if [ "$1" = "--run" ]; then
  "$OUT/makefiletest"
fi
