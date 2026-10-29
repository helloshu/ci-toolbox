#!/usr/bin/env bash
#
# zipalign + apksigner for an unsigned APK.
#
#   ./scripts/sign-apk.sh <unsigned.apk> <output.apk> [keystore.jks]
#
# Environment:
#   KEYSTORE_PASS / KEY_PASS / KEY_ALIAS   signing material
#   ANDROID_HOME or ANDROID_SDK_ROOT        to locate build-tools
#
set -euo pipefail

in="${1:?usage: $0 <unsigned.apk> <output.apk> [keystore.jks]}"
out="${2:?}"
ks="${3:-build-keystore.jks}"

: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-}}"
: "${KEYSTORE_PASS:=localbuild}"
: "${KEY_PASS:=$KEYSTORE_PASS}"

if [ -z "$ANDROID_HOME" ]; then
	echo "ANDROID_HOME/ANDROID_SDK_ROOT is not set" >&2
	exit 2
fi

# Discover the alias when the caller does not name one: a keystore holds a single
# private key here, and hard-coding the alias breaks whenever a different keystore
# is uploaded.
if [ -z "${KEY_ALIAS:-}" ]; then
	KEY_ALIAS="$(keytool -list -keystore "$ks" -storepass "$KEYSTORE_PASS" 2>/dev/null |
		awk -F, '/PrivateKeyEntry/ {print $1}' | head -1 | tr -d ' \r')"
	[ -n "$KEY_ALIAS" ] || { echo "cannot determine key alias in $ks" >&2; exit 2; }
	echo "key alias: $KEY_ALIAS"
fi

build_tools="$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -1)"
[ -n "$build_tools" ] || { echo "no build-tools in $ANDROID_HOME" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$build_tools/zipalign" -f -p 4 "$in" "$tmp/aligned.apk"
"$build_tools/apksigner" sign \
	--ks "$ks" \
	--ks-key-alias "$KEY_ALIAS" \
	--ks-pass "pass:$KEYSTORE_PASS" \
	--key-pass "pass:$KEY_PASS" \
	--v1-signing-enabled true \
	--v2-signing-enabled true \
	--out "$out" \
	"$tmp/aligned.apk"

"$build_tools/apksigner" verify --print-certs "$out" | head -3
echo "signed: $out"
