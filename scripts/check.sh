#!/usr/bin/env bash
# Quality checks before every handoff: build, format, lint, types.
# Tests run separately in Studio (docs/architecture.md, section 6).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
mkdir -p build
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
