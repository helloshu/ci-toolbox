#!/usr/bin/env bash
#
# Install Android SDK packages without android-actions/setup-android.
#
#   ./scripts/install-android-sdk.sh "platforms;android-37" "build-tools;37.0.0"
#
# The action calls `sdkmanager tools`, which no longer exists in the SDK
# repository, so it fails on current runner images. The runners already ship
# cmdline-tools and ANDROID_HOME, which is all we need.
#
# Preview/minor platforms (e.g. android-37.1) may live on a channel, so each
# package is retried on the canary channel before giving up.
#
set -euo pipefail

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK" ]; then
	echo "ANDROID_HOME/ANDROID_SDK_ROOT is not set" >&2
	exit 2
fi

SDKM="$(ls "$SDK"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | sort -V | tail -1 || true)"
if [ -z "$SDKM" ] || [ ! -x "$SDKM" ]; then
	SDKM="$(command -v sdkmanager || true)"
fi
if [ -z "$SDKM" ]; then
	echo "sdkmanager not found under $SDK" >&2
	exit 2
fi
echo "sdkmanager: $SDKM"
"$SDKM" --version || true

yes | "$SDKM" --licenses > /dev/null 2>&1 || true

install_pkg() {
	pkg="$1"
	for extra in "" "--channel=3" "--channel=2 --include_obsolete"; do
		# shellcheck disable=SC2086
		if "$SDKM" --install $extra "$pkg" > /tmp/sdk-install.log 2>&1; then
			echo "installed $pkg ${extra:-(stable channel)}"
			return 0
		fi
	done
	echo "!! failed to install $pkg, last output:" >&2
	tail -5 /tmp/sdk-install.log >&2
	echo "-- packages matching ${pkg#*;}: --" >&2
	"$SDKM" --list 2>/dev/null | grep -i "${pkg#*;}" | head -5 >&2 || true
	return 1
}

for pkg in "$@"; do
	if ! install_pkg "$pkg"; then
		# `platforms;android-37` does not exist: the SDK uses minor versions
		case "$pkg" in
			platforms\;android-[0-9]*) install_pkg "${pkg}.0" ;;
			*) exit 1 ;;
		esac
	fi
done
