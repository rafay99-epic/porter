#!/bin/zsh
# Builds the CURRENT branch as the Dev channel and installs it next to Stable.
# Stable (/Applications/Porter.app) is never touched — break Dev all you like.
# Usage: ./dev.sh
set -euo pipefail
cd "$(dirname "$0")"

PORTER_CHANNEL=dev ./build.sh

APP="build/Porter Dev.app"
DEST="/Applications/Porter Dev.app"

echo "Installing → $DEST"
osascript -e 'tell application "Porter Dev" to quit' 2>/dev/null || true
sleep 1
rm -rf "$DEST"
ditto "$APP" "$DEST"
open "$DEST"
echo "Launched Porter Dev — branch $(git rev-parse --abbrev-ref HEAD 2>/dev/null) @ $(git rev-parse --short HEAD 2>/dev/null)"
