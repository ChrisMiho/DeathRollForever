#!/usr/bin/env bash
# Fetch the libraries listed in .pkgmeta into ./Libs for local development.
# Uses the same packager as the release workflow, so local Libs match a release.
# Run from Git Bash: scripts/fetch-libs.sh
set -euo pipefail

PACKAGER_VERSION="v2.6.1" # keep in step with .github/workflows/release.yml
ADDON="DeathRollForever"

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

mkdir -p .release
packager=".release/release.sh"
if [ ! -f "$packager" ] || ! grep -q "$PACKAGER_VERSION" .release/.packager-version 2>/dev/null; then
	echo "Downloading packager $PACKAGER_VERSION"
	curl -fsSL "https://raw.githubusercontent.com/BigWigsMods/packager/$PACKAGER_VERSION/release.sh" -o "$packager"
	echo "$PACKAGER_VERSION" > .release/.packager-version
fi

# -d: no upload, -z: no zip. Builds .release/$ADDON with externals checked out.
bash "$packager" -d -z

rm -rf Libs
cp -r ".release/$ADDON/Libs" Libs
echo "Libraries copied into ./Libs"
