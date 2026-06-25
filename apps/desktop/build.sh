#!/bin/zsh
# Builds Porter.app from scratch. Usage: ./build.sh
#   PORTER_CHANNEL=stable (default) → Porter.app           com.syntaxlabtechnology.porter
#   PORTER_CHANNEL=nightly          → "Porter Nightly.app"  com.syntaxlabtechnology.porter.nightly
#   PORTER_CHANNEL=dev              → "Porter Dev.app"       com.syntaxlabtechnology.porter.dev
# The channels install side by side (different bundle id + name + data + icon).
# Stable + Nightly auto-update from GitHub releases; Dev never does.
set -euo pipefail
cd "$(dirname "$0")"

CHANNEL="${PORTER_CHANNEL:-stable}"
case "$CHANNEL" in
  stable)
    APP_NAME="Porter"
    BUNDLE_ID="com.syntaxlabtechnology.porter"
    ICON_CACHE="Resources/AppIcon.icns"
    ;;
  nightly)
    APP_NAME="Porter Nightly"
    BUNDLE_ID="com.syntaxlabtechnology.porter.nightly"
    ICON_CACHE="Resources/AppIcon-Nightly.icns"
    ;;
  dev)
    APP_NAME="Porter Dev"
    BUNDLE_ID="com.syntaxlabtechnology.porter.dev"
    ICON_CACHE="Resources/AppIcon-Dev.icns"
    ;;
  *)
    echo "PORTER_CHANNEL must be 'stable', 'nightly', or 'dev' (got '$CHANNEL')" >&2
    exit 1
    ;;
esac

echo "Compiling (arm64)…  [channel: $CHANNEL]"
# Apple Silicon only — single arm64 slice.
swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
BINARY="$BIN_DIR/Porter"

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Porter"
cp Resources/Info.plist "$APP/Contents/Info.plist"

PB=/usr/libexec/PlistBuddy
# Version is 0.<total commit count>. CI passes PORTER_VERSION; local builds compute
# it. Nightly/Dev append a channel suffix and stamp branch@sha for the About screen.
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo 0)
VERSION="${PORTER_VERSION:-0.$COMMIT_COUNT}"
if [[ "$CHANNEL" != "stable" ]]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
  VERSION="$VERSION-$CHANNEL"
  "$PB" -c "Add :PorterBuildInfo string $BRANCH@$SHA" "$APP/Contents/Info.plist" 2>/dev/null \
    || "$PB" -c "Set :PorterBuildInfo $BRANCH@$SHA" "$APP/Contents/Info.plist"
fi
"$PB" -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleName $APP_NAME" "$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleDisplayName $APP_NAME" "$APP/Contents/Info.plist"
"$PB" -c "Set :PorterChannel $CHANNEL" "$APP/Contents/Info.plist"
if [ -n "${PORTER_BUILD:-}" ]; then
  "$PB" -c "Add :PorterBuildNumber string $PORTER_BUILD" "$APP/Contents/Info.plist" 2>/dev/null \
    || "$PB" -c "Set :PorterBuildNumber $PORTER_BUILD" "$APP/Contents/Info.plist"
fi
echo "Version $VERSION  ($APP_NAME · $BUNDLE_ID)"

# Generate the channel's icon once; delete the cache file to force a re-render.
# Best-effort: a finicky icon render must never block a build.
if [ ! -f "$ICON_CACHE" ]; then
  echo "Rendering $CHANNEL icon…"
  PNG="/tmp/porter_icon_${CHANNEL}_1024.png"
  if swift Scripts/MakeIcon.swift "$PNG" "$CHANNEL" && [ -f "$PNG" ]; then
    ICONSET="/tmp/Porter-$CHANNEL.iconset"
    rm -rf "$ICONSET" && mkdir "$ICONSET"
    for s in 16 32 128 256 512; do
      sips -z $s $s "$PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
      d=$((s * 2))
      sips -z $d $d "$PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ICON_CACHE" || echo "⚠️  iconutil failed — shipping without an icon."
  else
    echo "⚠️  icon render failed — shipping without an icon."
  fi
fi
[ -f "$ICON_CACHE" ] && cp "$ICON_CACHE" "$APP/Contents/Resources/AppIcon.icns"

# Sign ad-hoc by default; set CODESIGN_IDENTITY to a Developer ID for notarization
# (adds hardened runtime + timestamp).
SIGN_ID="${CODESIGN_IDENTITY:--}"
SIGN_OPTS=(--force --sign "$SIGN_ID")
[[ "$SIGN_ID" != "-" ]] && SIGN_OPTS+=(--options runtime --timestamp)
echo "Signing…"
codesign "${SIGN_OPTS[@]}" "$APP"
echo "Done → $PWD/$APP"
