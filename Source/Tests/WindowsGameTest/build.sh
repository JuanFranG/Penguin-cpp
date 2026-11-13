#!/bin/sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"
fpc -vewn ${FPCFLAGS:-} -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/windowsgametest.lpr"
if [ "${1:-}" = --run ]; then "$OUT/windowsgametest"; fi
