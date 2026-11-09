#!/bin/zsh
# Packages the already-built channel app into a DMG with an /Applications symlink
# for drag-install, signs it, and notarizes + staples it when NOTARY_* is set.
# Run ./build.sh first. Usage: ./make-dmg.sh
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
OUT_DMG="build/$DMG_NAME"

# Sign the disk image wrapper with the identity build.sh used. This does not
# re-sign the .app inside (it keeps build.sh's hardened-runtime signature);
# never --deep here, it would strip the app's entitlements. UNSIGNED=1 (CI's PR
# packaging check) leaves it unsigned; that DMG is never published.
if [ "${UNSIGNED:-0}" != 1 ]; then
  SIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Syntax Labs (Private) Limited (MGH5K382YN)}"
  KEYCHAIN_ARGS=()
  [ -n "${CODESIGN_KEYCHAIN:-}" ] && KEYCHAIN_ARGS=(--keychain "$CODESIGN_KEYCHAIN")
  codesign --force --timestamp "${KEYCHAIN_ARGS[@]}" --sign "$SIGN_IDENTITY" "$OUT_DMG"
fi

# Notarize when CI hands over an App Store Connect API key (setup-signing.sh
# exports these on the publishing jobs; sign.sh does locally). Apple checks the
# DMG and the app inside it; stapling the ticket lets Gatekeeper pass it offline.
# A rejection fails the build, so an un-notarized Developer ID build never ships.
if [ -n "${NOTARY_KEY_PATH:-}" ]; then
  echo "Notarizing $OUT_DMG…"
  NOTARY=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER:?}")
  SUBMISSION="$(xcrun notarytool submit "$OUT_DMG" "${NOTARY[@]}" --output-format json)"
  ID="$(plutil -extract id raw -o - - <<< "$SUBMISSION")"
  echo "Submission $ID"
  # Apple can take over 30 minutes, and a single status request can time out,
  # which ends `notarytool wait`. Retry the wait so a dropped request isn't a
  # failed release. All attempts share one 2-hour deadline.
  STATUS=""
  DEADLINE=$((SECONDS + 7200))
  for attempt in 1 2 3 4 5; do
    LEFT=$((DEADLINE - SECONDS))
    [ "$LEFT" -gt 0 ] || break
    RESULT="$(xcrun notarytool wait "$ID" "${NOTARY[@]}" --timeout "${LEFT}s" --output-format json || true)"
    STATUS="$(plutil -extract status raw -o - - <<< "$RESULT" 2>/dev/null || true)"
    [ -n "$STATUS" ] && break
    echo "Notary status check failed (attempt $attempt/5), retrying"
  done
  echo "Notarization status: ${STATUS:-unknown}"
  if [ "$STATUS" != "Accepted" ]; then
    xcrun notarytool log "$ID" "${NOTARY[@]}" || true
    echo "error: notarization was not accepted" >&2
    exit 1
  fi
  xcrun stapler staple "$OUT_DMG"
  xcrun stapler validate "$OUT_DMG"
fi
echo "Done → $PWD/$OUT_DMG"
