#!/usr/bin/env bash
# Delete files or folders that Rojo syncs, without crashing `rojo serve`.
# Rojo 7.7.1 crashes (change_processor.rs, NotFound) when a folder goes away
# while it still has files, or right after its files change. So: delete the
# files, wait, then remove the empty folders one at a time, deepest first.
# Usage: scripts/rojo-safe-rm.sh <file-or-folder> ...
set -euo pipefail

FILE_WAIT=2
FOLDER_WAIT=1.5

if [ "$#" -eq 0 ]; then
	echo "usage: $0 <file-or-folder> ..." >&2
	exit 1
fi

for target in "$@"; do
	if [ -f "$target" ]; then
		rm "$target"
	elif [ -d "$target" ]; then
		find "$target" -type f -delete
		sleep "$FILE_WAIT"
		find "$target" -depth -type d | while read -r dir; do
			rmdir "$dir"
			sleep "$FOLDER_WAIT"
		done
	else
		echo "not found: $target" >&2
		exit 1
	fi
	echo "removed: $target"
done
