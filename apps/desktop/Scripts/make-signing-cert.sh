#!/bin/bash
# One-time generator for a stable, self-signed code-signing certificate.
#
# Why: ad-hoc signing (`codesign --sign -`) re-randomises the signature every build,
# so macOS treats each Porter update as a new app and drops its TCC grants (Full Disk
# Access, etc.) and Gatekeeper identity. A stable self-signed cert gives every build
# the same designated requirement, so the grant persists across updates. No Apple
# account / notarization is involved.
#
# This imports the cert into your login keychain (for local `CODESIGN_IDENTITY=… ./build.sh`)
# and prints the two GitHub secrets CI needs (MACOS_SIGN_CERT_P12, MACOS_SIGN_CERT_PASSWORD).
# The same cert/.p12 can be reused across every app in the family (Porter, Quill, …);
# each app's distinct bundle id still gets its own designated requirement.
set -euo pipefail

IDENTITY_NAME="${CODESIGN_IDENTITY:-Porter Local Signing}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
KEY="$WORK/key.pem"; CERT="$WORK/cert.pem"; P12="$WORK/signing.p12"

read -r -s -p "Choose a password for the exported .p12 (the CI secret): " P12_PW; echo
[ -n "$P12_PW" ] || { echo "Password cannot be empty." >&2; exit 1; }

# Escape `/` in the CN so a name with slashes can't break -subj DN parsing.
SUBJ_CN="${IDENTITY_NAME//\//\\/}"
# Keep stderr visible (only silence stdout) so cert-generation failures are diagnosable.
openssl req -x509 -newkey rsa:2048 -keyout "$KEY" -out "$CERT" -days 3650 -nodes \
  -subj "/CN=$SUBJ_CN" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" >/dev/null

# Legacy PBE so macOS `security import` can read it (OpenSSL 3 default cannot).
# env: keeps the password off argv; inline assignment keeps it out of later procs.
P12_PW="$P12_PW" openssl pkcs12 -export -inkey "$KEY" -in "$CERT" -out "$P12" \
  -name "$IDENTITY_NAME" -passout env:P12_PW \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

security import "$P12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$P12_PW" -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k "$HOME/Library/Keychains/login.keychain-db" "$CERT" 2>/dev/null \
  || echo "Note: could not auto-add trust; you may get a one-time keychain prompt on first sign."

echo; echo "Local: CODESIGN_IDENTITY=\"$IDENTITY_NAME\" ./build.sh"
echo "Secrets: MACOS_SIGN_CERT_PASSWORD=(password); MACOS_SIGN_CERT_P12=base64 below:"
base64 < "$P12"
