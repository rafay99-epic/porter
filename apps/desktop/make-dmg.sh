#!/bin/zsh
# Packages the already-built channel app into a DMG with an /Applications symlink
# for drag-install. Run ./build.sh first. Usage: ./make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

CHANNEL="${PORTER_CHANNEL:-stable}"
case "$CHANNEL" in
  stable)  APP_NAME="Porter";         DMG_NAME="Porter.dmg" ;;
  nightly) APP_NAME="Porter Nightly";  DMG_NAME="Porter-Nightly.dmg" ;;
  dev)     APP_NAME="Porter Dev";      DMG_NAME="Porter-Dev.dmg" ;;
  *) echo "PORTER_CHANNEL must be stable|nightly|dev (got '$CHANNEL')" >&2; exit 1 ;;
esac

APP="build/$APP_NAME.app"
[ -d "$APP" ] || { echo "Missing $APP — run ./build.sh first." >&2; exit 1; }

STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "build/$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "build/$DMG_NAME"
rm -rf "$STAGING"
echo "Done → $PWD/build/$DMG_NAME"
