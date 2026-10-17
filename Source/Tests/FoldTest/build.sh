#!/bin/sh
# Builds and runs the code folding test of the C++ highlighter
# (SynHighlighterCppFold). Needs Lazarus' lazbuild, for the SynEdit package.
# usage: Source/Tests/FoldTest/build.sh [--run]
#   LAZBUILD=...  lazbuild command (default: lazbuild), may include options
#                 such as --lazarusdir=...
#   WS=...        widgetset to build with (default: Lazarus' default), for
#                 example WS=nogui on a machine without a usable one
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

# -B: FPC 3.2.2 can stop with "Internal error 200611031" on incremental builds
if ! ${LAZBUILD:-lazbuild} -B ${WS:+--ws=$WS} "$HERE/foldtest.lpi" > "$OUT/build.log" 2>&1; then
  grep -E "Error|Fatal" "$OUT/build.log" || tail -20 "$OUT/build.log"
  echo "foldtest did not build; full log: $OUT/build.log"
  exit 1
fi

if [ "$1" = "--run" ]; then
  "$OUT/foldtest" "$HERE/../Folds/main.cpp"
fi
