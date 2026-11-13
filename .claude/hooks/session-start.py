#!/usr/bin/env python3
"""SessionStart hook (startup, clear and compact matchers).

- startup: adds the alarms from scripts/health.py, so a new session sees them
  before any work (closing-a-task skill: health check at every session start).
- compact and clear: add back the "Now" section of docs/handoff.md, so a
  compacted or cleared chat carries on from where the work stands.
The hooks guide says SessionStart context is the place for this; written
"run it at session start" rules were skipped (2026-11-03).
"""

import json
import os
import subprocess
import sys

# Context added after every compaction stays small; the file holds the rest.
WORD_CAP = 600


def alarms(project):
    try:
        out = subprocess.run(
            [sys.executable, os.path.join(project, "scripts", "health.py")],
            capture_output=True, text=True, cwd=project, timeout=20,
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""
    lines = out.splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("ALARMS")), None)
    if start is None:
        return ""
    return "Health check (scripts/health.py):\n" + "\n".join(lines[start:start + 12])


def now_section(project):
    try:
        with open(os.path.join(project, "docs", "handoff.md")) as f:
            lines = f.read().splitlines()
    except OSError:
        return ""
    kept, inside = [], False
    for line in lines:
        if line.startswith("## "):
            inside = line.strip() == "## Now"
            if not inside and kept:
                break
        if inside:
            kept.append(line)
    if not kept:
        return ""
    words = "\n".join(kept).split(" ")
    text = " ".join(words[:WORD_CAP])
    if len(words) > WORD_CAP:
        text += "\n... cut here; read docs/handoff.md for the rest."
    return "Where the work stands (docs/handoff.md):\n" + text


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    project = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    source = data.get("source")
    text = alarms(project) if source == "startup" else now_section(project) if source in ("compact", "clear") else ""
    if text:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}))


if __name__ == "__main__":
    main()
