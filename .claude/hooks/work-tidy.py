#!/usr/bin/env python3
"""Keeps work/ small: finished task files go to the Trash, new files go in a task folder.

- SessionStart (startup): moves every work/ folder or loose file whose newest file is older
  than STALE_DAYS to ~/.Trash/work-tidy-<date>/, keeping its place, so it can be put back.
  Folders in KEEP and any file a git file or the handoff names stay.
- PostToolUse (Write): a new file written straight into work/ gets a note to put it in
  work/<task>/ instead, so finished tasks can be moved out whole.
The prompting guide says scratch files are removed when the task ends; nobody did it by hand,
and work/ reached 413 MB and 2,780 files (2026-11-03).
"""

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import time

STALE_DAYS = 7
# Shared tools and records, plus backups that the closing-a-task skill clears at Gate 4.
KEEP = {"guides", "place-backups", "plan7-backup", "setup", "decisions", "bin", "tools", "dev",
        "archive", "job-check-fixtures", "task-clock.txt"}
LOOSE_OK = {"task-clock.txt"}


def newest(path):
    if os.path.isfile(path):
        return os.path.getmtime(path)
    times = [os.path.getmtime(os.path.join(a, b)) for a, _, bs in os.walk(path) for b in bs]
    return max(times, default=os.path.getmtime(path))


def cited(project):
    """Every work/ path a git file or the handoff names; moving them would break the link."""
    out = subprocess.run(["git", "-C", project, "ls-files"], capture_output=True, text=True, timeout=10).stdout
    names = set()
    for rel in out.splitlines() + ["docs/handoff.md", "docs/action-items.md"]:
        try:
            with open(os.path.join(project, rel), errors="ignore") as f:
                names.update(m.rstrip(".") for m in re.findall(r"work/([A-Za-z0-9._;/-]+)", f.read()))
        except OSError:
            pass
    return names


def stale_files(work, project, now):
    keep = cited(project)
    cutoff = now - STALE_DAYS * 86400
    for name in sorted(os.listdir(work)):
        path = os.path.join(work, name)
        if name in KEEP or name.startswith(".") or newest(path) >= cutoff:
            continue
        if os.path.isfile(path):
            if name not in keep:
                yield name
            continue
        for a, _, bs in os.walk(path):
            for b in bs:
                rel = os.path.relpath(os.path.join(a, b), work)
                if rel not in keep:
                    yield rel


def tidy(project, trash, now):
    work = os.path.join(project, "work")
    if not os.path.isdir(work):
        return ""
    dest = os.path.join(trash, "work-tidy-" + datetime.date.fromtimestamp(now).isoformat())
    moved = list(stale_files(work, project, now))
    for rel in moved:
        os.makedirs(os.path.dirname(os.path.join(dest, rel)), exist_ok=True)
        shutil.move(os.path.join(work, rel), os.path.join(dest, rel))
    for a, _, _ in os.walk(work, topdown=False):
        if a != work and not os.listdir(a):
            os.rmdir(a)
    if not moved:
        return ""
    return f"work-tidy: moved {len(moved)} work/ files untouched for {STALE_DAYS} days to {dest} (put back by moving them)."


def loose_note(project, path):
    path = os.path.abspath(os.path.join(project, path))
    if os.path.dirname(path) != os.path.join(project, "work") or os.path.basename(path) in LOOSE_OK:
        return ""
    return f"{os.path.relpath(path, project)} is loose in work/. Put task files in work/<task>/ so the whole folder can go once the task is done."


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    project = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    event = data.get("hook_event_name")
    if event == "SessionStart":
        trash = os.environ.get("WORK_TIDY_TRASH") or os.path.expanduser("~/.Trash")
        try:
            text = tidy(project, trash, time.time())
        except (OSError, subprocess.SubprocessError):
            return
    elif event == "PostToolUse":
        path = (data.get("tool_input") or {}).get("file_path")
        text = loose_note(project, path) if isinstance(path, str) and path else ""
    else:
        return
    if text:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}}))


if __name__ == "__main__":
    main()
