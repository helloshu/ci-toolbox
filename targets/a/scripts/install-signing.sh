#!/usr/bin/env bash
#
# Materialise the release signing material Keyguard expects.
#
#   ./targets/a/scripts/install-signing.sh <prepared-a-src-dir>
#
# Keyguard's build reads androidApp/a-release.keystore plus
# androidApp/a-release.properties (keys: key_alias, password_store,
# password_key).  Upstream only tracks the "qa" pair, so the release pair has to
# be provided: either from the SIGN_A_B64 secret (stable signature
# across builds) or generated on the fly (throwaway signature).
#
set -euo pipefail

src="${1:?usage: $0 <keyguard src dir>}"
app_dir="$src/androidApp"
[ -d "$app_dir" ] || { echo "no androidApp in $src" >&2; exit 2; }

ks="$app_dir/a-release.keystore"
props="$app_dir/a-release.properties"

: "${KEY_ALIAS:=keyguard}"
: "${KEYSTORE_PASS:=localbuild}"
: "${KEY_PASS:=$KEYSTORE_PASS}"

if [ -n "${SIGN_A_B64:-}" ]; then
	echo "$SIGN_A_B64" | base64 -d > "$ks"
	echo "keystore restored from SIGN_A_B64"
else
	echo "SIGN_A_B64 not set, generating a throwaway keystore"
	keytool -genkeypair -keystore "$ks" -alias "$KEY_ALIAS" \
		-keyalg RSA -keysize 4096 -validity 10000 \
		-storepass "$KEYSTORE_PASS" -keypass "$KEY_PASS" \
		-dname "CN=Local Build, OU=Self-Signed, O=Local, L=Local, ST=Local, C=CN" \
		2>&1 | tail -1
fi

cat > "$props" <<EOF
key_alias=$KEY_ALIAS
password_store=$KEYSTORE_PASS
password_key=$KEY_PASS
EOF

ls -l "$ks" "$props"
