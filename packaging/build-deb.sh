#!/bin/bash
# Builds the Penguin cpp package: build/deb/penguin-cpp_<version>_<arch>.deb
# usage: packaging/build-deb.sh [--no-build]
#   --no-build  package the ./penguin-cpp already built (Release, Qt5)
# Needs lazbuild (unless --no-build), dpkg-dev and binutils; runs lintian when
# it is installed.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION=$(sed -n "s/^ *DEVCPP_VERSION *= *'\([^']*\)'.*/\1/p" Source/Version.pas | tr -d '\r')
ARCH=$(dpkg --print-architecture)
[ -n "$VERSION" ] || { echo "No version in Source/Version.pas" >&2; exit 1; }

if [ "${1:-}" != "--no-build" ]; then
  lazbuild -B --ws=qt5 Source/penguin-cpp.lpi
fi
[ -x penguin-cpp ] || { echo "Build penguin-cpp first" >&2; exit 1; }

OUT=$ROOT/build/deb
STAGE=$OUT/penguin-cpp_${VERSION}_$ARCH
DEB=$STAGE.deb
rm -rf "$STAGE" "$DEB"
mkdir -p "$STAGE/DEBIAN"

# The program, in /usr/lib (it finds its files in ../../share/penguin-cpp)
install -D -m 755 penguin-cpp "$STAGE/usr/lib/penguin-cpp/penguin-cpp"
strip --strip-unneeded --remove-section=.comment --remove-section=.note "$STAGE/usr/lib/penguin-cpp/penguin-cpp"
mkdir -p "$STAGE/usr/bin"
ln -s ../lib/penguin-cpp/penguin-cpp "$STAGE/usr/bin/penguin-cpp"

# Its files: only what git tracks, nothing left over from a build
SHARE=$STAGE/usr/share/penguin-cpp
for DIR in Lang Templates Help Icons AStyle/doc ClangFormat/doc; do
  git ls-files -z -- "$DIR" | while IFS= read -r -d '' FILE; do
    install -D -m 644 "$FILE" "$SHARE/$FILE"
  done
done

# Fonts the interface and the editor prefer
FONTS=$STAGE/usr/share/fonts/truetype/penguin-cpp
mkdir -p "$FONTS"
install -m 644 Fonts/Heebo/static/Heebo-*.ttf Fonts/Source_Code_Pro/SourceCodePro-*.ttf "$FONTS"

# Menu entry, icons, the .dev file type
install -D -m 644 packaging/penguin-cpp.desktop "$STAGE/usr/share/applications/penguin-cpp.desktop"
install -D -m 644 packaging/penguin-cpp.xml "$STAGE/usr/share/mime/packages/penguin-cpp.xml"
for PNG in Source/Images/AppIcon/hicolor/*/apps/penguin-cpp.png; do
  SIZE=$(basename "$(dirname "$(dirname "$PNG")")")
  install -D -m 644 "$PNG" "$STAGE/usr/share/icons/hicolor/$SIZE/apps/penguin-cpp.png"
done
for PNG in packaging/icons/application-x-penguin-cpp-project-*.png; do
  N=${PNG##*-}; N=${N%.png}
  install -D -m 644 "$PNG" "$STAGE/usr/share/icons/hicolor/${N}x$N/mimetypes/application-x-penguin-cpp-project.png"
done

# Manual pages and documentation
mkdir -p "$STAGE/usr/share/man/man1" "$STAGE/usr/share/man/es/man1" "$STAGE/usr/share/doc/penguin-cpp"
sed "s/@VERSION@/$VERSION/" packaging/penguin-cpp.1 | gzip -9n > "$STAGE/usr/share/man/man1/penguin-cpp.1.gz"
sed "s/@VERSION@/$VERSION/" packaging/penguin-cpp.es.1 | gzip -9n > "$STAGE/usr/share/man/es/man1/penguin-cpp.1.gz"
install -m 644 packaging/copyright "$STAGE/usr/share/doc/penguin-cpp/copyright"
gzip -9n < packaging/changelog > "$STAGE/usr/share/doc/penguin-cpp/changelog.gz"

find "$STAGE/usr" -type d -exec chmod 755 {} +
find "$STAGE/usr" -type f -exec chmod 644 {} +
chmod 755 "$STAGE/usr/lib/penguin-cpp/penguin-cpp"

# The libraries the program links to (libc6, libqt5pas1...), as dpkg sees them
SHLIBS=
if command -v dpkg-shlibdeps > /dev/null; then
  TMP=$(mktemp -d)
  mkdir "$TMP/debian"
  printf 'Source: penguin-cpp\n\nPackage: penguin-cpp\nArchitecture: any\n' > "$TMP/debian/control"
  SHLIBS=$(cd "$TMP" && dpkg-shlibdeps -O "$STAGE/usr/lib/penguin-cpp/penguin-cpp" | sed -n 's/^shlibs:Depends=//p')
  rm -rf "$TMP"
fi
[ -n "$SHLIBS" ] || SHLIBS="libc6, libqt5pas1"

SIZE=$(du -sk --apparent-size "$STAGE/usr" | cut -f1)
sed -e "s/@VERSION@/$VERSION/" -e "s/@ARCH@/$ARCH/" -e "s/@SIZE@/$SIZE/" -e "s/@SHLIBS@/$SHLIBS/" \
  packaging/control.in > "$STAGE/DEBIAN/control"
(cd "$STAGE" && find usr -type f -print0 | sort -z | xargs -0 md5sum) > "$STAGE/DEBIAN/md5sums"
chmod 644 "$STAGE/DEBIAN/control" "$STAGE/DEBIAN/md5sums"

dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$DEB"
echo "Built $DEB"

if command -v lintian > /dev/null; then
  lintian --info --display-info --fail-on error "$DEB"
fi
