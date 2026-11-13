#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build pinned GNU Make for the self-contained Windows toolchain on ARM64 macOS.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$ROOT/build/compat-bundle/tools}
SRC=$ROOT/build/compat-sources
WORK=$ROOT/build/compat-build
mkdir -p "$SRC" "$WORK" "$OUT"
ARCHIVE=$SRC/make-4.4.1.tar.gz
SHA=dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3
if [ ! -f "$ARCHIVE" ]; then
  curl --proto '=https' --proto-redir '=https' -fL -o "$ARCHIVE.part" https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz
  mv "$ARCHIVE.part" "$ARCHIVE"
fi
echo "$SHA  $ARCHIVE" | shasum -a 256 -c -
tar -xzf "$ARCHIVE" -C "$WORK"
cd "$WORK/make-4.4.1"
CFLAGS='-O2 -mmacosx-version-min=26.0' ./configure --prefix="$OUT" --without-guile --disable-nls
/usr/bin/make -j4
/usr/bin/make install
mkdir -p "$OUT/share/licenses/make"
cp COPYING AUTHORS README "$ARCHIVE" "$OUT/share/licenses/make/"
lipo -verify_arch arm64 "$OUT/bin/make"
