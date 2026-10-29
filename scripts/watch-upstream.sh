#!/usr/bin/env bash
#
# 3-day upstream watch: detect new commits, verify the patch set still applies,
# and report what the caller should do.
#
#   ./scripts/watch-upstream.sh [--force]
#
# For every target under targets/:
#   - read the pinned commit from targets/<t>/source.env
#   - read the current head of the upstream default branch (git ls-remote)
#   - same commit            -> "clean"
#   - new commit + patches ok -> "build"   (source.env is bumped in place)
#   - new commit + patches ko -> "broken"  (pin untouched, needs patch rework)
#
# Outputs:
#   $GITHUB_OUTPUT   builds=a,b   broken=c   any=true|false
#   $GITHUB_STEP_SUMMARY (when set)  human readable table
#   plan.json        machine readable plan for the workflow
#
set -euo pipefail

force=""
[ "${1:-}" = "--force" ] && force=1

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

builds=()
broken=()
clean=()
plan="["
first=1

echo "| target | pinned | upstream head | patches | action |" > /tmp/watch-table.md
echo "|---|---|---|---|---|" >> /tmp/watch-table.md

for dir in targets/*/; do
	t="${dir%/}"; t="${t##*/}"
	env_file="targets/$t/source.env"
	[ -f "$env_file" ] || continue
	# shellcheck disable=SC1090
	set -a; . "$env_file"; set +a
	name="$NAME"

	head_sha="$(git ls-remote "$REPO" HEAD | cut -f1)"
	pinned="$SHA"

	if [ -z "$head_sha" ]; then
		echo "!! $t: cannot read $REPO" >&2
		broken+=("$t")
		echo "| $name | ${pinned:0:8} | unreachable | - | broken |" >> /tmp/watch-table.md
		continue
	fi

	if [ "$head_sha" = "$pinned" ] && [ -z "$force" ]; then
		clean+=("$t")
		echo "| $name | ${pinned:0:8} | ${head_sha:0:8} | - | clean |" >> /tmp/watch-table.md
		continue
	fi

	# patches are already materialised by fetch-patches.sh in the workflow
	patches=(targets/"$t"/patches/*.patch)
	if [ ${#patches[@]} -eq 0 ] || [ ! -e "${patches[0]}" ]; then
		echo "!! $t: no patches present (run scripts/fetch-patches.sh first)" >&2
		broken+=("$t")
		echo "| $name | ${pinned:0:8} | ${head_sha:0:8} | missing | broken |" >> /tmp/watch-table.md
		continue
	fi

	probe="$(mktemp -d)"
	if git -C "$probe" init -q 2>/dev/null && \
	   git -C "$probe" fetch -q --depth 1 "$REPO" "$head_sha" 2>/dev/null && \
	   git -C "$probe" checkout -q FETCH_HEAD 2>/dev/null; then
		ok=1
		for p in "${patches[@]}"; do
			git -C "$probe" apply --check -p1 "$(pwd)/$p" 2>/dev/null || { ok=0; break; }
		done
	else
		ok=0
	fi
	rm -rf "$probe"

	if [ "$ok" = 1 ]; then
		sed -i "s/^SHA=.*/SHA=$head_sha/" "$env_file"
		builds+=("$t")
		echo "| $name | ${pinned:0:8} | ${head_sha:0:8} | apply ok | **build** |" >> /tmp/watch-table.md
	else
		broken+=("$t")
		echo "| $name | ${pinned:0:8} | ${head_sha:0:8} | apply FAILED | **needs rework** |" >> /tmp/watch-table.md
	fi

	if [ $first -eq 1 ]; then first=0; else plan="$plan,"; fi
	plan="$plan{\"target\":\"$t\",\"new_sha\":\"$head_sha\",\"patches_ok\":$([ "$ok" = 1 ] && echo true || echo false)}"
done

plan="$plan]"
echo "$plan" > plan.json

joined() { [ $# -eq 0 ] && echo "" || (IFS=,; echo "$*"); }
json_list() {
	if [ $# -eq 0 ]; then echo '[]'
	else printf '[%s]' "$(printf '"%s",' "$@" | sed 's/,$//')"
	fi
}
builds_s="$(joined ${builds[@]+"${builds[@]}"})"
broken_s="$(joined ${broken[@]+"${broken[@]}"})"
builds_json="$(json_list ${builds[@]+"${builds[@]}"})"
broken_json="$(json_list ${broken[@]+"${broken[@]}"})"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
	{
		echo "builds=$builds_s"
		echo "builds_json=$builds_json"
		echo "broken_json=$broken_json"
		echo "broken=$broken_s"
		echo "any=$([ -n "${builds_s}${broken_s}" ] && echo true || echo false)"
	} >> "$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "## upstream watch"
		echo
		if [ -n "${force:-}" ]; then echo "_(forced run: patches re-verified at the pinned commit)_"; echo; fi
		cat /tmp/watch-table.md
		echo
		echo "rebuild: ${builds_s:-none} · broken: ${broken_s:-none} · unchanged: $(joined ${clean[@]+"${clean[@]}"})"
	} >> "$GITHUB_STEP_SUMMARY"
fi

echo "plan: $plan"
echo "builds=[${builds_s}] broken=[${broken_s}]"
