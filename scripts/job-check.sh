#!/usr/bin/env bash
# Checks for Studio job scripts in work/ before their first paste.
# Three Task 54 Studio calls were lost to job scripts that stopped before
# judging anything (Lesson 76). This catches the mistakes a shell can see.
# Usage: scripts/job-check.sh work/t54/server-p.luau [more files]
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
if [ $# -eq 0 ]; then
	echo "usage: scripts/job-check.sh <job.luau> [more]"
	exit 2
fi
fail=0

echo "== Size (Lesson 63: at most 300 lines per job file)"
for f in "$@"; do
	n=$(wc -l <"$f" | tr -d ' ')
	if [ "$n" -gt 300 ]; then
		echo "  $f: $n lines, over 300; split it"
		fail=1
	fi
done

echo "== Lines starting with \"(\" (Lesson 7)"
if grep -nE '^\s*\(' "$@"; then
	fail=1
fi

echo "== Clones of modules that use script.Parent (Lesson 74)"
# A module that loads its neighbours through script.Parent fails as an
# unparented clone, so a job must require it the plain way.
parent_users=$(grep -rlE 'script\.Parent' src tools --include='*.luau' |
	xargs -n1 basename | sed -E 's/\.luau$//; s/^init\.(server|client)$//' | grep -v '^$' | sort -u)
for name in $parent_users; do
	if grep -nE "\b${name}\b[^-]*:Clone\(\)" "$@"; then
		echo "  ^ $name uses script.Parent; require it the plain way"
		fail=1
	fi
done

echo "== string.format behind a ... wrapper (Lesson 79: the type check can't see its arguments)"
if grep -nE 'string\.format\([A-Za-z_]+, *\.\.\.\)' "$@"; then
	echo "  ^ call string.format at each site with a literal format; wrap booleans in tostring"
	fail=1
fi

echo "== Format"
stylua --check "$@" || fail=1

echo "== Lint"
selene "$@" || fail=1

echo "== Types"
mkdir -p build
if [ ! -f build/globalTypes.d.luau ]; then
	curl -sfL -o build/globalTypes.d.luau \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
	--definitions=@roblox=build/globalTypes.d.luau "$@" || fail=1

if [ "$fail" -ne 0 ]; then
	echo "Job check FAILED: fix the lines above before any Studio paste."
	exit 1
fi
echo "Job check passed. code_lead still reads the job against the lessons before its first paste (Lesson 76)."
