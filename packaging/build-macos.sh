#!/bin/bash
# Builds Penguin cpp for macOS (Apple Silicon):
#   build/macos/Penguin cpp.app
#   build/macos/Penguin-cpp-<version>-arm64.dmg
# usage: packaging/build-macos.sh [--no-build]
#   --no-build  package the ./penguin-cpp already built (Release, Cocoa)
# The build needs Lazarus 3.8 and Free Pascal 3.2.4 (3.2.2 cannot link
# Cocoa programs with the current linker); LAZBUILD is the lazbuild to run,
# with its options, e.g.
#   LAZBUILD="$HOME/lazarus/lazbuild --lazarusdir=$HOME/lazarus --compiler=$HOME/fpc/bin/fpc"
# The app is not signed by a developer: the program keeps only the ad hoc
# signature the linker gives every Apple Silicon program ("LEEME - README.txt"
# in the disk image tells how to open it the first time).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION=$(sed -n "s/^ *DEVCPP_VERSION *= *'\([^']*\)'.*/\1/p" Source/Version.pas | tr -d '\r')
[ -n "$VERSION" ] || { echo "No version in Source/Version.pas" >&2; exit 1; }

if [ "${1:-}" != "--no-build" ]; then
  ${LAZBUILD:-lazbuild} -B --ws=cocoa Source/penguin-cpp.lpi
fi
[ -x penguin-cpp ] || { echo "Build penguin-cpp first" >&2; exit 1; }
[ "$(lipo -archs penguin-cpp)" = arm64 ] || { echo "penguin-cpp is not an arm64 program" >&2; exit 1; }

OUT=$ROOT/build/macos
APP=$OUT/Penguin\ cpp.app
DMG=$OUT/Penguin-cpp-$VERSION-arm64.dmg
rm -rf "$APP" "$DMG" "$OUT/dmg"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# The program, without its local symbols (strip signs it again, as the
# linker did)
install -m 755 penguin-cpp "$APP/Contents/MacOS/penguin-cpp"
strip -x "$APP/Contents/MacOS/penguin-cpp"
codesign --verify "$APP/Contents/MacOS/penguin-cpp"

# Its files, in Contents/Resources (where the program looks for them): only
# what git tracks, nothing left over from a build
RES=$APP/Contents/Resources
for DIR in Lang Templates Help Icons AStyle/doc ClangFormat/doc; do
  git ls-files -z -- "$DIR" | while IFS= read -r -d '' FILE; do
    install -d "$RES/$(dirname "$FILE")"
    install -m 644 "$FILE" "$RES/$FILE"
  done
done
install -m 644 COPYING.txt LICENSE "$RES/"

# The icon, from the Linux one's sizes
ICONSET=$OUT/penguin-cpp.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
PNG=Source/Images/AppIcon/hicolor
for SIZE in 16 32 128 256 512; do
  cp "$PNG/${SIZE}x$SIZE/apps/penguin-cpp.png" "$ICONSET/icon_${SIZE}x$SIZE.png"
done
cp "$PNG/32x32/apps/penguin-cpp.png" "$ICONSET/icon_16x16@2x.png"
cp "$PNG/64x64/apps/penguin-cpp.png" "$ICONSET/icon_32x32@2x.png"
cp "$PNG/256x256/apps/penguin-cpp.png" "$ICONSET/icon_128x128@2x.png"
cp "$PNG/512x512/apps/penguin-cpp.png" "$ICONSET/icon_256x256@2x.png"
cp Source/Images/AppIcon/penguin-cpp-large.png "$ICONSET/icon_512x512@2x.png" # 1024
iconutil -c icns -o "$RES/penguin-cpp.icns" "$ICONSET"
rm -rf "$ICONSET"

sed "s/@VERSION@/$VERSION/g" packaging/Info.plist.in > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
printf 'APPLpeng' > "$APP/Contents/PkgInfo"
echo "Built $APP"

# The disk image: the app, the Applications folder to drag it to, and how
# to open it the first time
STAGE=$OUT/dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
install -m 644 packaging/macos-LEEME.txt "$STAGE/LEEME - README.txt"
hdiutil create -quiet -volname "Penguin cpp $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGE"
hdiutil verify -quiet "$DMG"
echo "Built $DMG"
