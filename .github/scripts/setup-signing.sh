#!/bin/bash
# CI: import the stable self-signed code-signing cert into an ephemeral keychain and
# export CODESIGN_IDENTITY (the var build.sh reads) so the released build is signed
# with a stable designated requirement — TCC grants persist across auto-updates.
#
# Wired ONLY into release jobs (push to main / push to nightly), never a pull_request
# job: a PR branch could run untrusted code and exfiltrate the cert secret.
# If the secrets are absent the build proceeds ad-hoc (with a warning).
set -euo pipefail

if [ -z "${MACOS_SIGN_CERT_P12:-}" ] || [ -z "${MACOS_SIGN_CERT_PASSWORD:-}" ]; then
  echo "::warning::MACOS_SIGN_CERT_P12/PASSWORD not set — building ad-hoc; released builds will need a manual permission re-grant on update."
  exit 0
fi

KEYCHAIN="$RUNNER_TEMP/app-signing.keychain-db"
KEYCHAIN_PW="$(openssl rand -base64 24)"
CERT_P12="$RUNNER_TEMP/app-signing.p12"

security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"

echo "$MACOS_SIGN_CERT_P12" | base64 --decode > "$CERT_P12"
security import "$CERT_P12" -k "$KEYCHAIN" -P "$MACOS_SIGN_CERT_PASSWORD" -T /usr/bin/codesign
rm -f "$CERT_P12"

security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PW" "$KEYCHAIN" >/dev/null

# Keep the new keychain in the search list alongside the existing ones.
existing_keychains=()
while IFS= read -r kc; do
  kc="${kc//\"/}"; kc="${kc#"${kc%%[![:space:]]*}"}"
  [ -n "$kc" ] && existing_keychains+=("$kc")
done < <(security list-keychains -d user)
security list-keychains -d user -s "$KEYCHAIN" "${existing_keychains[@]}"

IDENTITY="$(security find-identity -p codesigning "$KEYCHAIN" | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)"
[ -n "$IDENTITY" ] || { echo "::error::No code-signing identity found after import."; exit 1; }
echo "CODESIGN_IDENTITY=$IDENTITY" >> "$GITHUB_ENV"
echo "Configured stable signing identity: $IDENTITY"
