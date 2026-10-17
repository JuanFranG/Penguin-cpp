#!/bin/sh
# Checks the IDE's forms (.lfm) against the Pascal classes they are loaded
# into: unknown classes, properties, enumeration/set values and event
# handlers. Needs python3 and Lazarus' lazbuild.
# usage: Source/Tests/LfmCheck/check.sh
#   LAZBUILD=...  lazbuild command (default: lazbuild), may include options
#                 such as --lazarusdir=...
#   WS=...        widgetset to build with (default: Lazarus' default), for
#                 example WS=nogui on a machine without a usable one
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../.." && pwd)
OUT="$HERE/build"
mkdir -p "$OUT"

# FormatterOptionsFrm is not used by the IDE; Tools/, VCL/SynEdit and
# VCL/SVGIconImageList are not part of it; lib/ is build output
LFMS=$(cd "$SRC" && find . -name '*.lfm' \
  ! -path './Tests/*' ! -path './Tools/*' ! -path './lib/*' ! -path './VCL/SynEdit/*' ! -path './VCL/SVGIconImageList/*' \
  ! -name FormatterOptionsFrm.lfm | sed 's#^\./##' | sort)
python3 "$HERE/lfmparse.py" "$OUT" "$SRC" $LFMS

# -B: FPC 3.2.2 can stop with "Internal error 200611031" on incremental builds
if ! ${LAZBUILD:-lazbuild} -B ${WS:+--ws=$WS} "$HERE/lfmcheck.lpi" > "$OUT/build.log" 2>&1; then
  grep -E "Error|Fatal" "$OUT/build.log" || tail -20 "$OUT/build.log"
  echo "lfmcheck did not build; full log: $OUT/build.log"
  exit 1
fi
"$OUT/lfmcheck" "$OUT/checks.tsv"
