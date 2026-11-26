#!/bin/bash
# Pinned upstream UCRT toolchain, included in the .deb rather than fetched at install time.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
NAME=llvm-mingw-20261104-ucrt-ubuntu-22.04-x86_64
SHA=919380403de87dca3c581c2053230cd298af5e891286628ba0613b7fed370926
CACHE="$ROOT/build/linux-toolchain"
mkdir -p "$CACHE"
ARCHIVE="$CACHE/$NAME.tar.xz"
if [ ! -f "$ARCHIVE" ]; then
  curl -fL --retry 3 -o "$ARCHIVE.part" "https://github.com/mstorsjo/llvm-mingw/releases/download/20261104/$NAME.tar.xz"
  mv "$ARCHIVE.part" "$ARCHIVE"
fi
printf '%s  %s\n' "$SHA" "$ARCHIVE" | sha256sum -c -
if [ ! -d "$CACHE/$NAME" ]; then
  tar -xJf "$ARCHIVE" -C "$CACHE"
fi
DEST="$1/usr/lib/penguin-cpp/windows-toolchain"
mkdir -p "$DEST"
cp -a "$CACHE/$NAME/." "$DEST/"
mkdir -p "$1/usr/share/penguin-cpp/Compat/windows"
ln -s ../../../../lib/penguin-cpp/windows-toolchain "$1/usr/share/penguin-cpp/Compat/windows/toolchain"
