#!/usr/bin/env bash
#
# Fetch the pinned upstream commit of one project and apply its patch set.
#
#   ./scripts/prepare-upstream.sh <project-dir> <dest-dir> [--check]
#
# <project-dir> is one of targets/a/, targets/b/, targets/c/.
# With --check the patches are only validated against the fetched tree
# (git apply --check); nothing is written after the clone.
#
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "usage: $0 <project-dir> <dest-dir> [--check]" >&2
	exit 2
fi

proj="${1%/}"
dest="$2"
mode="${3:-}"

env_file="$proj/source.env"
[ -f "$env_file" ] || { echo "missing $env_file" >&2; exit 2; }

# shellcheck disable=SC1090
set -a; . "$env_file"; set +a
: "${REPO:?}" "${SHA:?}" "${NAME:?}"

echo "== $NAME: $REPO @ $SHA"

rm -rf "$dest"
mkdir -p "$dest"
git -C "$dest" init -q
git -C "$dest" config user.email "build@localhost"
git -C "$dest" config user.name "build"
git -C "$dest" remote add origin "$REPO"
git -C "$dest" fetch -q --depth 1 origin "$SHA"
git -C "$dest" checkout -q FETCH_HEAD

shopt -s nullglob
patches=("$proj"/patches/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
	# Never build the pristine upstream by accident: an empty patch directory means
	# scripts/fetch-patches.sh did not run or had no token.
	echo "no patches in $proj/patches (run scripts/fetch-patches.sh first)" >&2
	exit 3
fi

for p in "${patches[@]}"; do
	p_abs="$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
	if [ "$mode" = "--check" ]; then
		if git -C "$dest" apply --check -p1 "$p_abs"; then
			echo "ok      $(basename "$p")"
		else
			echo "FAILED  $(basename "$p")" >&2
			exit 1
		fi
	else
		git -C "$dest" apply -p1 "$p_abs"
		echo "applied $(basename "$p")"
	fi
done

if [ "$mode" != "--check" ]; then
	git -C "$dest" add -A
	git -C "$dest" -c commit.gpgsign=false commit -q -m "apply $NAME patch set"
	echo "$NAME ready at $dest"
fi
