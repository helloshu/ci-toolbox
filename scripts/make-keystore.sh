#!/usr/bin/env bash
#
# Create the keystore needed to sign the Android builds.
#
#   ./scripts/make-keystore.sh <output.jks> [alias]
#
# Passwords come from the environment when provided, otherwise deterministic
# local values are used (self-signed builds only, never for store uploads).
#
set -euo pipefail

out="${1:?usage: $0 <output.jks> [alias]}"
alias="${2:-build}"

: "${KEYSTORE_PASS:=localbuild}"
: "${KEY_PASS:=$KEYSTORE_PASS}"

if [ -f "$out" ]; then
	echo "keystore already present: $out"
	exit 0
fi

mkdir -p "$(dirname "$out")"
keytool -genkeypair \
	-keystore "$out" \
	-alias "$alias" \
	-keyalg RSA -keysize 4096 -validity 10000 \
	-storepass "$KEYSTORE_PASS" \
	-keypass "$KEY_PASS" \
	-dname "CN=Local Pro Build, OU=Self-Signed, O=Local, L=Local, ST=Local, C=CN" \
	2>&1 | tail -2

echo "created $out (alias=$alias)"
