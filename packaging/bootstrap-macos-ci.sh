#!/bin/bash
# Isolated versions used by the Cocoa build; no system compiler replacement.
set -euo pipefail
[ "$(uname -m)" = arm64 ]
ROOT=${1:?Usage: bootstrap-macos-ci.sh TOOLCHAIN_DIRECTORY}
mkdir -p "$ROOT"
ROOT=$(cd "$ROOT" && pwd)
FPC_REV=2a105860ee8a8687f3c66918b3441469c0370db4
LAZ_REV=57e899e4bbe50b6653ec20434bdb7799aa629e06
SDK=$(xcrun --show-sdk-path)
if [ ! -x "$ROOT/fpc/bin/fpc" ]; then
  BOOTSTRAP=$(command -v fpc)
  git clone https://gitlab.com/freepascal.org/fpc/source.git "$ROOT/fpc-src"
  git -C "$ROOT/fpc-src" checkout --detach "$FPC_REV"
  make -C "$ROOT/fpc-src" all FPC="$BOOTSTRAP" OPT="-XR$SDK"
  make -C "$ROOT/fpc-src" install INSTALL_PREFIX="$ROOT/fpc"
  mkdir -p "$ROOT/fpc/etc"
  "$ROOT/fpc/bin/fpcmkcfg" -d "basepath=$ROOT/fpc/lib/fpc/3.2.4" -o "$ROOT/fpc/etc/fpc.cfg"
  printf '\n-XR%s\n-Fl%s/usr/lib\n' "$SDK" "$SDK" >> "$ROOT/fpc/etc/fpc.cfg"
fi
# The driver otherwise finds Homebrew's ppca64 (3.2.2) on PATH, even when
# --compiler points to our pinned fpc. Keep the backend beside the driver.
ln -sfn ../lib/fpc/3.2.4/ppca64 "$ROOT/fpc/bin/ppca64"
export PATH="$ROOT/fpc/bin:$PATH"
export PPC_CONFIG_PATH="$ROOT/fpc/etc"
[ "$("$ROOT/fpc/bin/fpc" -iV)" = 3.2.4 ]
if [ ! -x "$ROOT/lazarus/lazbuild" ]; then
  git clone https://gitlab.com/freepascal.org/lazarus/lazarus.git "$ROOT/lazarus"
  git -C "$ROOT/lazarus" checkout --detach "$LAZ_REV"
  make -C "$ROOT/lazarus" lazbuild LCL_PLATFORM=cocoa FPC="$ROOT/fpc/bin/fpc" OPT="-XR$SDK"
fi
"$ROOT/fpc/bin/fpc" -iV
"$ROOT/lazarus/lazbuild" --version
