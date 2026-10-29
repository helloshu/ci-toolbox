#!/usr/bin/env bash
#
# Optionally replace the in-repo patch set with one fetched from a private repo.
#
#   ./scripts/fetch-patches.sh <target-dir>
#
# Used by the public "orchestration" repository: the workflow file and the build
# logic are public, while the patches themselves stay in a private repository that
# only a token can read.
#
# Environment:
#   PATCHES_REPO   e.g. owner/keyguard-patches   (absent -> keep in-repo patches)
#   PATCHES_TOKEN  fine-grained PAT, contents:read on that repository
#   PATCHES_REF    branch/tag/sha, default: main
#
set -euo pipefail

proj="${1:?usage: $0 <target-dir>}"
name="$(basename "$proj")"

if [ -z "${PATCHES_REPO:-}" ] || [ -z "${PATCHES_TOKEN:-}" ]; then
	echo "PATCHES_REPO/PATCHES_TOKEN not set, using the patch set in $proj/patches"
	exit 0
fi

ref="${PATCHES_REF:-main}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "fetching patches from $PATCHES_REPO@$ref"
git clone -q --depth 1 --branch "$ref" \
	"https://x-access-token:${PATCHES_TOKEN}@github.com/${PATCHES_REPO}.git" "$tmp/repo" 2>/dev/null ||
	git clone -q "https://x-access-token:${PATCHES_TOKEN}@github.com/${PATCHES_REPO}.git" "$tmp/repo"
git -C "$tmp/repo" checkout -q "$ref" 2>/dev/null || true

src="$tmp/repo/$name"
[ -d "$src" ] || { echo "no $name/ in $PATCHES_REPO" >&2; exit 1; }

rm -f "$proj"/patches/*.patch
cp "$src"/*.patch "$proj/patches/"
echo "patches now:"
ls -1 "$proj/patches"
