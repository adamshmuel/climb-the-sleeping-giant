#!/usr/bin/env python3
"""PreToolUse hook (Bash): block folder deletes and moves that crash Rojo.

Rojo 7.7.1 crashes when a synced folder is removed or moved while it still
has files. Deleting single files is safe. Folders under the synced roots must
go through scripts/rojo-safe-rm.sh.
"""

import json
import os
import re
import shlex
import sys

SYNCED = ("src", "tools")
# In a desktop worktree session CLAUDE_PROJECT_DIR is the main checkout, so a folder
# inside a worktree is checked against that worktree (code.claude.com/docs/en/worktrees).
WORKTREE = re.compile(r"^(.*?/\.claude/worktrees/[^/]+)(?:/|$)")


def synced_folder(path, cwd, project):
    full = os.path.normpath(os.path.join(cwd, os.path.expanduser(path)))
    match = WORKTREE.match(full)
    project = match.group(1) if match else project
    for root in SYNCED:
        base = os.path.join(project, root)
        if full == base or full.startswith(base + os.sep):
            return os.path.isdir(full)
    return False


def words_of(command):
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        return list(lexer)
    except ValueError:
        return command.split()


def problem(command, cwd, project):
    # scripts/rojo-safe-rm.sh is not rm, rmdir or mv, so it passes on its own.
    words = words_of(command)
    for index, word in enumerate(words):
        if word == "cd" and index + 1 < len(words):
            cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(words[index + 1])))
            continue
        name = os.path.basename(word)
        if name not in ("rm", "rmdir", "mv") or (index and words[index - 1] not in ("", ";", "&&", "||", "|", "git", "sudo", "(")):
            continue
        for arg in words[index + 1 :]:
            if arg in (";", "&&", "||", "|", ")"):
                break
            if arg.startswith("-"):
                continue
            if synced_folder(arg, cwd, project):
                return arg
    return None


def main():
    data = json.load(sys.stdin)
    command = (data.get("tool_input") or {}).get("command", "")
    cwd = data.get("cwd") or os.getcwd()
    project = os.environ.get("CLAUDE_PROJECT_DIR") or cwd
    folder = problem(command, cwd, project)
    if folder:
        print(
            f"Blocked: '{folder}' is a folder Rojo syncs. Removing or moving a synced folder in one go "
            f"crashes `rojo serve`, and the user then has to click Connect. Use "
            f"`scripts/rojo-safe-rm.sh {folder}` instead (it deletes the files, waits, then removes the "
            f"empty folders). To move a folder, copy it, then remove the old one with the script.",
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
