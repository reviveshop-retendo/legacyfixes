#!/usr/bin/env bash
#
# Build every per-app package, the all-in-one metapackage, and the repo
# metadata. Intended to run inside the Docker image (see docker/Dockerfile),
# but it also works on any machine with Theos + dpkg tooling installed.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../repo.conf
source "$ROOT/repo.conf"

if [[ -z "${THEOS:-}" ]]; then
    echo "error: \$THEOS is not set. Run this through scripts/docker-build.sh." >&2
    exit 1
fi

APP_PACKAGES=(youtube youtubekids facebook messenger)
DEB_OUT="$ROOT/build/debs"

rm -rf "$ROOT/build"
mkdir -p "$DEB_OUT"

for pkg in "${APP_PACKAGES[@]}"; do
    dir="$ROOT/packages/$pkg"
    echo "==> building $pkg"
    make -C "$dir" clean >/dev/null 2>&1 || true
    make -C "$dir" package FINALPACKAGE=1
    shopt -s nullglob
    debs=("$dir"/packages/*.deb)
    shopt -u nullglob
    if [[ ${#debs[@]} -eq 0 ]]; then
        echo "error: $pkg produced no .deb" >&2
        exit 1
    fi
    cp "${debs[@]}" "$DEB_OUT/"
done

echo "==> building all-in-one metapackage"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/DEBIAN"
sed "s/__VERSION__/$VERSION/g" "$ROOT/packages/allinone/control" > "$stage/DEBIAN/control"
chmod 0755 "$stage" "$stage/DEBIAN"
dpkg-deb --build --root-owner-group "$stage" \
    "$DEB_OUT/com.legacyfixes.allinone_${VERSION}_iphoneos-arm.deb" >/dev/null
rm -rf "$stage"
trap - EXIT

echo "==> building repo metadata"
"$ROOT/scripts/make-repo.sh"

echo
echo "Done. Debs:  $DEB_OUT"
echo "      Repo:  $ROOT/repo"
echo "      Add:   $REPO_URL"
