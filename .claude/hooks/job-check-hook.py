#!/usr/bin/env python3
"""PostToolUse hook (Edit|Write): check a handoff, card or Studio job the moment it is written.

The writing-handoffs skill says every handoff and job passes scripts/job-check.sh
before the builder or runner starts, and that a card stays short. Cards kept
skipping it (Task 4g), so this runs it on every write in work/ and sends any
failure straight back. A card or handoff over 800 words is sent back too.
"""

import json
import os
import re
import subprocess
import sys

CARD = re.compile(r"(handoff|card)[^/]*\.md$")
WORD_CAP = 800


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
    work = os.path.join(project, "work") + os.sep
    if not path.startswith(work):
        return
    name = os.path.basename(path)
    if CARD.search(name):
        args, problems = ["--handoff", path], []
        try:
            with open(path) as f:
                words = len(f.read().split())
        except OSError:
            words = 0
        if words > WORD_CAP:
            problems.append(f"{name} is {words} words; a card stays under {WORD_CAP} (writing-handoffs skill). Cut it.")
    elif name.endswith(".luau"):
        args, problems = [path], []
    else:
        return
    script = os.path.join(project, "scripts", "job-check.sh")
    # A check that cannot run is reported, never passed (fail closed).
    try:
        out = subprocess.run([script, *args], capture_output=True, text=True, cwd=project, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as error:
        problems.append(f"The job check could not run ({type(error).__name__}), so {name} is unchecked. Run scripts/job-check.sh {' '.join(args)} by hand.")
        out = None
    if out is not None and out.returncode != 0:
        tail = "\n".join((out.stdout + out.stderr).strip().splitlines()[-15:])
        problems.append(
            f"scripts/job-check.sh {' '.join(args)} failed:\n{tail}\n"
            "Fix the file before anyone runs it. If it is one part of a split job, check the parts with --joined."
        )
    if problems:
        print(json.dumps({"decision": "block", "reason": "\n".join(problems)}))


if __name__ == "__main__":
    main()
