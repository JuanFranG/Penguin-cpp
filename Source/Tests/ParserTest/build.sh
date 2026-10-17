#!/bin/sh
# Builds and runs the parser console test with Free Pascal (no Lazarus needed).
# usage: Source/Tests/ParserTest/build.sh [--run]
#   FPCFLAGS="-Cr -Co -Ct -CR -Sa -gh -gl" adds runtime checks and leak reports
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

fpc -vewn $FPCFLAGS -FU"$OUT" -FE"$OUT" -Fu"$SRC" -Fu"$SRC/VCL/ClassBrowsing" "$HERE/parsertest.lpr"

if [ "$1" = "--run" ]; then
  echo
  echo "=== preprocessor.cpp: #if/#elif/#else handling"
  "$OUT/parsertest" --no-system \
    --expect good_chain_14 --expect good_if --expect good_else --expect good_after_nested \
    --expect good_ifdef --expect good_defined --expect good_div --expect good_end_of_file \
    --reject bad_chain_11 --reject bad_chain_17 --reject bad_chain_else --reject bad_else \
    --reject bad_if0 --reject bad_nested_if --reject bad_nested_else --reject bad_ifndef --reject bad_div \
    "$HERE/preprocessor.cpp"

  echo
  echo "=== sample.cpp: with the system compiler's headers"
  "$OUT/parsertest" \
    --expect Shape --expect Circle --expect Area --expect Color --expect NameList \
    --expect globalCounter --expect PrintNames --expect main --expect GREETING \
    --expect cout --expect vector --expect basic_string \
    "$HERE/sample.cpp"
fi
