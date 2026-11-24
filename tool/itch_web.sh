#!/usr/bin/env bash
# Builds the web version as a zip for itch.io (HTML5 upload, played in the browser).
#   tool/itch_web.sh [output-dir]   (default: build/itch)
# itch.io serves the game from a sub-path inside an iframe, so the <base href> must be relative
# and the service worker is left out.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/itch}"
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
rm -rf build/web
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
sed -i 's#<base href="/">#<base href="./">#' build/web/index.html
grep -q '<base href="./">' build/web/index.html
mkdir -p "$OUT"
ZIP="$(cd "$OUT" && pwd)/w-calc-web-$VERSION.zip"
rm -f "$ZIP"
(cd build/web && zip -qr "$ZIP" .)
echo "itch.io web build: $ZIP"
