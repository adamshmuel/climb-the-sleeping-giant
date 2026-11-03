#!/usr/bin/env python3
"""PostToolUse hook (Edit|Write): keep files under the 1000-line limit the moment they grow.

agent-workflow.md ("No big files") caps every file in src, tools, scripts, docs, .claude and work
at 1000 lines. scripts/check.sh and scripts/health.py only report it when they run, so a file
could grow past 900 with nobody told. Over 900 lines adds a note to split it by topic in the
same task; over 1000 sends the edit back. Smaller limits (job files, CLAUDE.md, rules, skills)
stay with their own checks.
"""

import json
import os
import sys

FOLDERS = ["src", "tools", "scripts", "docs", ".claude", "work"]
WARN = 900
LIMIT = 1000


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    inp = data.get("tool_input") if isinstance(data, dict) else None
    path = inp.get("file_path") if isinstance(inp, dict) else None
    if not isinstance(path, str) or not path:
        return
    project = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    # A relative path is the project's, not this hook's working folder.
    path = os.path.abspath(os.path.join(project, path))
    if not any(path.startswith(os.path.join(project, folder) + os.sep) for folder in FOLDERS):
        return
    try:
        with open(path, errors="replace") as f:
            lines = sum(1 for _ in f)
    except OSError:
        return
    name = os.path.relpath(path, project)
    if lines > LIMIT:
        reason = f"{name} is {lines} lines, over the {LIMIT}-line limit (agent-workflow.md, \"No big files\"). Split it by topic now and list the parts in its folder's index."
        print(json.dumps({"decision": "block", "reason": reason}))
    elif lines > WARN:
        note = f"{name} is {lines} lines, close to the {LIMIT}-line limit. Split it by topic in this task, before it reaches {LIMIT}."
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": note}}))


if __name__ == "__main__":
    main()
