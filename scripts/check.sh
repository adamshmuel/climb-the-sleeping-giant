#!/usr/bin/env bash
# Quality checks before every handoff: build, format, lint, types.
# Tests run separately in Studio (docs/architecture.md, section 6).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
mkdir -p build
echo "== Size"
# No .luau or .md file in src, tools or docs goes over 1000 lines (agent-workflow.md, "No big files").
sizes=$(find src tools docs \( -name '*.luau' -o -name '*.md' \) -type f -print0 |
	xargs -0 wc -l |
	awk '$2 != "total" || NF > 2 { n = $1; sub(/^ *[0-9]+ /, ""); print n "\t" $0 }')
too_big=$(echo "$sizes" | awk -F'\t' '$1 > 1000 { print "  " $2 " (" $1 " lines)" }')
near_limit=$(echo "$sizes" | awk -F'\t' '$1 > 900 && $1 <= 1000 { print "  " $2 " (" $1 " lines)" }')
if [ -n "$near_limit" ]; then
	echo "Note: close to the 1000-line limit:"
	echo "$near_limit"
fi
if [ -n "$too_big" ]; then
	echo "Too big (over 1000 lines), split by topic:"
	echo "$too_big"
	exit 1
fi
echo "== Fresh modules in the ready-made Studio scripts"
# Studio keeps the first copy of a module it loaded, even after Rojo syncs a newer one, so an
# Edit-time paste that requires a module the plain way runs old code (Lesson 74, Setup 7).
plain=$(grep -nE 'require(Module)?\(' scripts/studio/*.luau | grep -v ':Clone()' | grep -vE '= require :: any' || true)
if [ -n "$plain" ]; then
	echo "$plain"
	echo "Each line above requires a module without :Clone(), so Studio may run an old copy (Lesson 74)."
	exit 1
fi
echo "== Build"
rojo build default.project.json -o build/check.rbxl
echo "== Format"
stylua --check src tools
echo "== Lint"
selene src tools
echo "== Types"
if [ ! -f build/globalTypes.d.luau ]; then
	curl -sfL -o build/globalTypes.d.luau \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
	--definitions=@roblox=build/globalTypes.d.luau \
	--ignore "Packages/**" --ignore "DevPackages/**" \
	src tools
echo "All checks passed."
