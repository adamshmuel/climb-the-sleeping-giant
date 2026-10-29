#!/usr/bin/env python3
"""Refuse osascript (AppleScript) in Bash, for every agent.

osascript and System Events can pop up macOS permission prompts that Adam
would have to answer ("Adam only approves"). A Task 13 Play builder tried
`osascript` to mute the Mac because its handoff said "Sound muted".
Sound in a Play job is muted inside the game, from the job itself.
"""

import json
import re
import sys


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    command = (data.get("tool_input") or {}).get("command") or ""
    # Only the command itself, so a file named after it (this hook) can still be staged or read.
    if not re.search(r"(^|[\s;&|(`$/])osascript(\s|$)|System Events", command):
        return
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                "osascript and System Events are not used in this project: they can pop up macOS prompts "
                "the user would have to answer. Mute sound inside the Play job itself (the game's own sounds), "
                "or report that it isn't muted."
            ),
        }
    }
    print(json.dumps(out))


if __name__ == "__main__":
    main()
