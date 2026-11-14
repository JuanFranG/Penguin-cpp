#!/bin/bash
# Installs (or updates) Penguin cpp on a Mac with Apple Silicon, in one line:
#   curl -fsSL https://juanfrang.github.io/Penguin-cpp/install-macos.sh | bash
# It downloads the disk image of the latest release, puts the app in
# /Applications (in ~/Applications when the user cannot write there) and
# asks for Apple's Command Line Tools if they are missing.
# INSTALL_DIR, if set, is the folder to install in.
set -euo pipefail

REPO=JuanFranG/Penguin-cpp
APP_NAME="Penguin cpp.app"
TARGET_APP_NAME=${INSTALL_APP_NAME:-$APP_NAME}
case "$TARGET_APP_NAME" in
  */*|.|..|'') echo "Invalid app name" >&2; exit 1 ;;
esac
case "$TARGET_APP_NAME" in *.app) ;; *) echo "Invalid app name" >&2; exit 1 ;; esac

say() { printf '%s\n' "$*"; }
fail() { printf 'Penguin cpp: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "este instalador es para macOS (para Linux, ver https://juanfrang.github.io/Penguin-cpp/)"
[ "$(uname -m)" = arm64 ] || fail "Penguin cpp para macOS necesita un Mac con Apple Silicon (M1 o posterior)"
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=${MACOS_VERSION%%.*}
[[ "$MACOS_MAJOR" =~ ^[0-9]+$ ]] && [ "$MACOS_MAJOR" -ge 26 ] ||
  fail "Penguin cpp necesita macOS 26 o posterior (detectado: $MACOS_VERSION)"
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
STAGE=
KEEP_STAGE=false
cleanup() {
  if [ -d "$MOUNT" ]; then hdiutil detach -quiet "$MOUNT" 2>/dev/null || true; fi
  if [ -n "$STAGE" ]; then
    # A signal or failed rename must not remove the only surviving copy.
    if [ -d "$STAGE/previous.app" ] && [ ! -e "$DEST/$TARGET_APP_NAME" ]; then
      mv "$STAGE/previous.app" "$DEST/$TARGET_APP_NAME" || KEEP_STAGE=true
    fi
    if [ "$KEEP_STAGE" = false ]; then rm -rf "$STAGE";
    else say "La copia anterior se conserva en $STAGE/previous.app" >&2; fi
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

say "Buscando la última versión..."
# The latest release's page leads to its tag (.../releases/tag/v0.2.0).
# GitHub's API would answer only 60 times an hour to one address, and a
# classroom goes out through one.
TAG=$(curl --proto '=https' --proto-redir '=https' --max-redirs 5 --connect-timeout 15 --max-time 30 -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")
TAG=${TAG##*/}
[[ "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
  fail "no se encontró una versión estable en https://github.com/$REPO/releases"

ASSET="Penguin-cpp-${TAG#v}-arm64.dmg"
if [ -f "$DEST/$TARGET_APP_NAME/Contents/Resources/Compat/windows/environment.json" ]; then
  ASSET="Penguin-cpp-${TAG#v}-COMPLETE-UNSIGNED.dmg"
fi
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

say "Descargando ${URL##*/}..."
curl --proto '=https' --proto-redir '=https' --max-redirs 5 --connect-timeout 15 --max-time 600 -fL --progress-bar -o "$WORK/penguin-cpp.dmg" "$URL"

mkdir "$MOUNT"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$WORK/penguin-cpp.dmg"
[ -d "$MOUNT/$APP_NAME" ] || fail "la imagen de disco no tiene $APP_NAME"
codesign --verify --deep --strict "$MOUNT/$APP_NAME" || fail "la app de la imagen de disco no está íntegra"

say "Instalando en $DEST..."
# Copy and verify on the destination filesystem before touching the old app.
STAGE=$(mktemp -d "$DEST/.penguin-cpp-update.XXXXXX")
ditto "$MOUNT/$APP_NAME" "$STAGE/$APP_NAME"
codesign --verify --deep --strict "$STAGE/$APP_NAME" || fail "no se pudo verificar la copia nueva"
# Never silently replace a complete Windows environment with a native-only DMG.
if [ -f "$DEST/$TARGET_APP_NAME/Contents/Resources/Compat/windows/environment.json" ] &&
   [ ! -f "$STAGE/$APP_NAME/Contents/Resources/Compat/windows/environment.json" ]; then
  fail "la descarga solo incluye el IDE nativo; conserva el entorno completo. Instala un paquete completo compatible para actualizar esta copia"
fi
if [ -e "$DEST/$TARGET_APP_NAME" ]; then mv "$DEST/$TARGET_APP_NAME" "$STAGE/previous.app"; fi
if ! mv "$STAGE/$APP_NAME" "$DEST/$TARGET_APP_NAME"; then
  fail "no se pudo reemplazar la app; se restaurará la versión anterior"
fi

if xcode-select -p > /dev/null 2>&1; then
  say "Penguin cpp está instalado: ábrelo desde $DEST o el Launchpad."
else
  say "Penguin cpp está instalado. Para compilar y depurar necesita las Command"
  say "Line Tools de Apple (clang, make, lldb): macOS va a pedir instalarlas."
  xcode-select --install 2> /dev/null || true
fi
