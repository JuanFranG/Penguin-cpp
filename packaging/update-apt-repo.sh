#!/bin/bash
# Adds .deb packages to the Penguin cpp APT repository and signs it.
# usage: packaging/update-apt-repo.sh REPO PACKAGE.deb...
#   REPO  the repository's folder (the gh-pages branch, served by GitHub
#         Pages at https://juanfrang.github.io/Penguin-cpp/)
# Signs with the secret key gpg has (the CI imports it from the
# APT_SIGNING_KEY secret). Needs apt-utils (apt-ftparchive) and gnupg.
#
# The layout is the one apt expects:
#   pool/main/p/penguin-cpp/*.deb         every version published
#   dists/stable/main/binary-amd64/Packages(.gz)
#   dists/stable/Release, InRelease, Release.gpg
#   penguin-cpp.gpg, penguin-cpp.asc      the public key, for signed-by
set -euo pipefail

REPO=$1
shift
[ $# -gt 0 ] || { echo "usage: $0 REPO PACKAGE.deb..." >&2; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$REPO/pool/main/p/penguin-cpp"
for DEB in "$@"; do
  cp "$DEB" "$REPO/pool/main/p/penguin-cpp/"
done

cd "$REPO"
ARCHS=amd64
for ARCH in $ARCHS; do
  DIR=dists/stable/main/binary-$ARCH
  mkdir -p "$DIR"
  apt-ftparchive --arch "$ARCH" packages pool > "$DIR/Packages"
  gzip -9nkf "$DIR/Packages"
done

apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="Penguin cpp" \
  -o APT::FTPArchive::Release::Label="Penguin cpp" \
  -o APT::FTPArchive::Release::Suite=stable \
  -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Architectures="$ARCHS" \
  -o APT::FTPArchive::Release::Components=main \
  -o APT::FTPArchive::Release::Description="Penguin cpp, a C and C++ IDE for learning" \
  release dists/stable > dists/stable/Release

gpg --batch --yes --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --batch --yes --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release

# The public key, binary for apt's signed-by and armored for people
gpg --batch --yes --export > penguin-cpp.gpg
gpg --batch --yes --armor --export > penguin-cpp.asc

# The page people see, the macOS installer it offers, and no Jekyll (it
# would hide some files)
cp "$HERE/apt-repo-index.html" index.html
cp "$HERE/install-macos.sh" install-macos.sh
touch .nojekyll
echo "APT repository updated in $(pwd)"
