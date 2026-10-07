#!/usr/bin/env bash
# PostToolUse hook: format and lint any .luau file Claude just edited.
# Exit 2 sends stderr back to Claude so lint errors get fixed.
file=$(jq -r '.tool_input.file_path // empty')
[[ "$file" == *.luau && -f "$file" ]] || exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0
PATH="$HOME/.rokit/bin:$PATH"

if ! command -v stylua >/dev/null || ! command -v selene >/dev/null; then
	echo "luau-check: stylua/selene not found, run 'rokit install'" >&2
	exit 2
fi

stylua "$file" 2>&1 >/dev/null | sed 's/^/stylua: /' >&2
if ! out=$(selene --display-style quiet "$file" 2>&1); then
	echo "$out" >&2
	exit 2
fi
