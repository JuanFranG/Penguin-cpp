#!/bin/sh
# Builds and runs the OS layer console test with Free Pascal (no Lazarus needed).
# usage: Source/Tests/PlatformTest/build.sh [--run]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

fpc -vewn -FU"$OUT" -FE"$OUT" -Fu"$SRC" -Fu"$SRC/VCL/devFileMonitor" "$HERE/platformtest.lpr"

if [ "$1" = "--run" ]; then
  echo
  echo "=== default environment"
  (unset XDG_CONFIG_HOME; "$OUT/platformtest")
  echo
  echo "=== with XDG_CONFIG_HOME set"
  XDG_CONFIG_HOME=/tmp/xdg-config-test "$OUT/platformtest"
fi
