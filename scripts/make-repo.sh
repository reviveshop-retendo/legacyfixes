#!/usr/bin/env bash
#
# Turn build/debs/*.deb into a Cydia/Sileo/Zebra repository under repo/.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../repo.conf
source "$ROOT/repo.conf"

DEB_DIR="$ROOT/build/debs"
OUT="$ROOT/repo"

if [[ ! -d "$DEB_DIR" ]]; then
    echo "error: $DEB_DIR does not exist; run scripts/build.sh first" >&2
    exit 1
fi

rm -rf "$OUT/debs"
mkdir -p "$OUT/debs"
cp "$DEB_DIR"/*.deb "$OUT/debs/"

cd "$OUT"

# -m keeps multiple versions of the same package (useful when rolling back).
dpkg-scanpackages -m debs /dev/null 2>/dev/null | sed 's|^Filename: \./|Filename: |' > Packages
gzip -9ncf Packages > Packages.gz

size_of() { stat -c '%s' "$1"; }
md5_of()  { md5sum "$1" | cut -d' ' -f1; }
sha_of()  { sha256sum "$1" | cut -d' ' -f1; }
now="$(LC_ALL=C date -Ru)"

{
    echo "Origin: $REPO_ORIGIN"
    echo "Label: $REPO_LABEL"
    echo "Suite: stable"
    echo "Version: $VERSION"
    echo "Codename: ios"
    echo "Architectures: iphoneos-arm"
    echo "Components: main"
    echo "Description: $REPO_DESCRIPTION"
    echo "Date: $now"
    echo "MD5Sum:"
    for f in Packages Packages.gz; do
        echo " $(md5_of "$f") $(size_of "$f") $f"
    done
    echo "SHA256:"
    for f in Packages Packages.gz; do
        echo " $(sha_of "$f") $(size_of "$f") $f"
    done
} > Release

# Sign if a key was supplied (see scripts/sign-repo.sh for details).
if [[ -n "${REPO_SIGNING_KEY:-}" ]]; then
    gpg --batch --yes --default-key "$REPO_SIGNING_KEY" \
        --armor --detach-sign --output Release.gpg Release
    gpg --batch --yes --default-key "$REPO_SIGNING_KEY" \
        --clearsign --output InRelease Release
fi

echo "Repo metadata written to $OUT"
echo "Packages: $(grep -c '^Package:' Packages)"
