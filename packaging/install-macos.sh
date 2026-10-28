#!/bin/bash
# Installs (or updates) Penguin cpp on a Mac with Apple Silicon, in one line:
#   curl -fsSL https://juanfrang.github.io/Penguin-cpp/install-macos.sh | bash
# It downloads the disk image of the latest release, puts the app in
# /Applications (in ~/Applications when the user cannot write there) and
# asks for Apple's Command Line Tools if they are missing. Downloaded with
# curl, the app is not marked as coming from the internet, so macOS opens
# it without asking (it is not signed by an Apple developer).
# INSTALL_DIR, if set, is the folder to install in.
set -euo pipefail

REPO=JuanFranG/Penguin-cpp
APP_NAME="Penguin cpp.app"

say() { printf '%s\n' "$*"; }
fail() { printf 'Penguin cpp: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "este instalador es para macOS (para Linux, ver https://juanfrang.github.io/Penguin-cpp/)"
[ "$(uname -m)" = arm64 ] || fail "Penguin cpp para macOS necesita un Mac con Apple Silicon (M1 o posterior)"
if pgrep -qf "$APP_NAME/Contents/MacOS/penguin-cpp"; then
  fail "cierra Penguin cpp y vuelve a ejecutar el instalador"
fi

if [ -n "${INSTALL_DIR:-}" ]; then
  DEST=$INSTALL_DIR
elif [ -w /Applications ]; then
  DEST=/Applications
else
  DEST=$HOME/Applications
fi
mkdir -p "$DEST"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/penguin-cpp-install.XXXXXX")
MOUNT=$WORK/mount
cleanup() {
  if [ -d "$MOUNT" ]; then hdiutil detach -quiet "$MOUNT" 2>/dev/null || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT

say "Buscando la última versión..."
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
  sed -n 's/.*"browser_download_url": *"\([^"]*-arm64\.dmg\)".*/\1/p' | head -n 1)
[ -n "$URL" ] || fail "la última versión de https://github.com/$REPO no tiene imagen de disco para macOS"

say "Descargando ${URL##*/}..."
curl -fL --progress-bar -o "$WORK/penguin-cpp.dmg" "$URL"

mkdir "$MOUNT"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$WORK/penguin-cpp.dmg"
[ -d "$MOUNT/$APP_NAME" ] || fail "la imagen de disco no tiene $APP_NAME"
codesign --verify --deep --strict "$MOUNT/$APP_NAME" || fail "la app de la imagen de disco no está íntegra"

say "Instalando en $DEST..."
rm -rf "${DEST:?}/$APP_NAME"
ditto "$MOUNT/$APP_NAME" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

if xcode-select -p > /dev/null 2>&1; then
  say "Penguin cpp está instalado: ábrelo desde $DEST o el Launchpad."
else
  say "Penguin cpp está instalado. Para compilar y depurar necesita las Command"
  say "Line Tools de Apple (clang, make, lldb): macOS va a pedir instalarlas."
  xcode-select --install 2> /dev/null || true
fi
