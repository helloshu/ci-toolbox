#!/usr/bin/env bash
#
# Pack a prepared (patched) source tree for release.
#
#   ./scripts/make-source-tarball.sh <src-dir> <out.tar.gz>
#
# The tarball is the "corresponding source" shipped next to the binaries of a
# GPLv3 project (the GPLv3 upstream), so it must contain the patched sources and the
# upstream LICENSE files, but no build output or VCS metadata.
#
set -euo pipefail

src="${1:?usage: $0 <src-dir> <out.tar.gz>}"
out="${2:?}"

[ -d "$src" ] || { echo "not a directory: $src" >&2; exit 2; }

parent="$(cd "$(dirname "$src")" && pwd)"
name="$(basename "$src")"
mkdir -p "$(dirname "$out")"
out_abs="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"

tar -C "$parent" \
	--exclude-vcs \
	--exclude='*/build' \
	--exclude='*/.gradle' \
	--exclude='*/.kotlin' \
	--exclude='*/node_modules' \
	--exclude='*/target' \
	--exclude='*.apk' \
	-czf "$out_abs" "$name"

echo "source: $out_abs ($(du -h "$out_abs" | cut -f1))"
