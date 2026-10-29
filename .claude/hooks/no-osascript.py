#!/usr/bin/env python3
"""Refuse osascript (AppleScript) in Bash, for every agent.

osascript and System Events can pop up macOS permission prompts that Adam
would have to answer ("Adam only approves"). A Task 13 Play builder tried
`osascript` to mute the Mac because its handoff said "Sound muted".
Sound in a Play job is muted inside the game, from the job itself.

The command is split into words the way the shell reads it, so a full path,
a quoted `bash -c "..."` or `X=osascript` is caught, while a file named after
this hook can still be staged or read. Anything it can't read is refused.
"""

import json
import os
import re
import shlex
import sys

BLOCKED = {"osascript", "osacompile"}
# Belt and braces over the raw text: the name as its own word anywhere (in $(...), backticks,
# quotes), but not inside a file name like this hook's.
RAW = re.compile(r"(?<![A-Za-z0-9_.-])(osascript|osacompile)(?![A-Za-z0-9_.-])", re.I)
REASON = (
    "osascript and System Events are not used in this project: they can pop up macOS prompts "
    "the user would have to answer. Mute sound inside the Play job itself (the game's own sounds), "
    "or report that it isn't muted."
)


def words_of(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def blocked(command, depth=0):
    if "system events" in command.lower() or RAW.search(command):
        return True
    try:
        words = words_of(command)
    except ValueError:
        # The whole command must parse; a quoted part that doesn't (a commit
        # message with "can't") can't run as a command either, and the raw
        # check above has already scanned it.
        if depth == 0:
            raise
        return False
    for word in words:
        # X=osascript, or a quoted command run by bash -c / eval.
        value = word.split("=", 1)[1] if "=" in word else word
        if os.path.basename(value).lower() in BLOCKED:
            return True
        if depth < 3 and any(c.isspace() for c in word) and blocked(word, depth + 1):
            return True
    return False


def deny(reason):
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )


def main():
    try:
        data = json.load(sys.stdin)
        tool_input = data.get("tool_input") if isinstance(data, dict) else None
        command = (tool_input.get("command") if isinstance(tool_input, dict) else "") or ""
        if blocked(command):
            deny(REASON)
    except Exception:
        deny("no-osascript hook couldn't read this command, so it is refused. Write it more simply.")


if __name__ == "__main__":
    main()
