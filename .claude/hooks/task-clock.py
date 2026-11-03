#!/usr/bin/env python3
"""UserPromptSubmit and PreToolUse (Agent) hook: the task clock (CLAUDE.md, "Speed rules").

The main chat writes one line to work/task-clock.txt when a task starts:
    Task 5 | small | 2026-11-03 12:00
The class is "small" (10-minute limit) or "task" (1 hour, also a new part).
"done" closes it. Past the limit, every prompt and every agent start gets the
red-flag note until the line changes. Overruns kept going unseen because the
clock was only a written rule (2026-11-03).
"""

import datetime
import json
import os
import sys

LIMITS = {"small": 10, "task": 60}
FORMAT = "%Y-%m-%d %H:%M"


def note(event, text):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}}))


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    event = data.get("hook_event_name") or "UserPromptSubmit"
    project = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    try:
        with open(os.path.join(project, "work", "task-clock.txt")) as f:
            line = f.read().strip()
    except OSError:
        return
    if not line:
        return
    parts = [p.strip() for p in line.split("|")]
    if len(parts) == 3 and parts[1] == "done":
        return
    try:
        task, kind, start = parts
        limit = LIMITS[kind]
        started = datetime.datetime.strptime(start, FORMAT)
    except (ValueError, KeyError):
        note(event, f"work/task-clock.txt can't be read. Write it as: Task 5 | small | {datetime.datetime.now():{FORMAT}} (small, task or done).")
        return
    minutes = int((datetime.datetime.now() - started).total_seconds() // 60)
    if minutes > limit:
        note(
            event,
            f"Red flag: {task} has run {minutes} min against its {limit}-min limit. Stop the work at a safe point, "
            "tell the user in one line what is done and what isn't, and follow the stop-and-step-back skill. "
            "Restart the clock in work/task-clock.txt only when work starts again from the decided way.",
        )


if __name__ == "__main__":
    main()
