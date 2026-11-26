#!/bin/sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"
fpc -Mdelphi -vewn ${FPCFLAGS:-} -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/filetransactionstest.lpr"
fpc -Mdelphi -vewn ${FPCFLAGS:-} -FU"$OUT" -FE"$OUT" -Fu"$SRC" "$HERE/processresulttest.lpr"
fpc -Mdelphi -vewn ${FPCFLAGS:-} -FU"$OUT" -FE"$OUT" -Fu"$HERE/stubs" -Fu"$SRC" "$HERE/executortest.lpr"
mkdir -p "$OUT/config"
fpc -Mdelphi -vewn ${FPCFLAGS:-} -FU"$OUT/config" -FE"$OUT/config" -Fu"$HERE/config-stubs" -Fu"$SRC" "$HERE/configtest.lpr"
if [ "${1:-}" = --run ]; then
  python3 "$HERE/transactions_test.py" "$OUT/filetransactionstest"
  "$OUT/config/configtest"
  "$OUT/processresulttest"
  "$OUT/executortest"
  python3 "$HERE/mac_terminal_test.py"
fi
