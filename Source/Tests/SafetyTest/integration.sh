#!/bin/sh
# Actual Cocoa/Qt5 editor/compiler code, deterministic dialog responses.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
cd "$ROOT"
if [ -z "${WS:-}" ]; then
  case "$(uname -s)" in Darwin) WS=cocoa ;; *) WS=qt5 ;; esac
fi
mkdir -p "$HERE/build"
# The main project generates the icon resources used by the real main form.
${LAZBUILD:-lazbuild} --ws="$WS" Source/penguin-cpp.lpi > "$HERE/build/main-build.log" 2>&1
${LAZBUILD:-lazbuild} -B --ws="$WS" "$HERE/integrationtest.lpi" > "$HERE/build/integration-build.log" 2>&1
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/penguin-safety-integration.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
mkdir -p "$TEST_DIR/home"
HOME="$TEST_DIR/home" XDG_CONFIG_HOME="$TEST_DIR/home/.config" "$HERE/build/integrationtest" -c "$TEST_DIR"
