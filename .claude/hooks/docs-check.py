#!/usr/bin/env python3
"""PostToolUse hook (Edit|Write) and task-close check: docs follow the docs.md rule.

docs.md ("Layout", "Specs and plans") asks for three things a script can check:
a doc over 100 lines starts with a contents list, links to other docs and their headings
work, and specs and plans have no "TBD". As a hook it checks the one doc just edited and
adds a note; nothing is sent back. With --all it checks every tracked doc and prints one
line per problem (scripts/health.py runs it at every task close).
Usage: python3 .claude/hooks/docs-check.py --all
"""

import json
import os
import re
import subprocess
import sys

LONG = 100
CONTENTS_WITHIN = 20  # the contents list sits under the title, before the first section
TBD_FOLDERS = ("docs/specs/", "docs/plans/")


def slug(heading, seen):
    """GitHub's heading anchor: lower case, punctuation dropped, spaces to dashes, -1 for repeats."""
    base = re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")
    count = seen.get(base, 0)
    seen[base] = count + 1
    return base if count == 0 else f"{base}-{count}"


def outside_code(lines):
    fence = False
    for number, line in enumerate(lines, 1):
        if line.startswith("```"):
            fence = not fence
            continue
        if not fence:
            yield number, line


def anchors(path):
    try:
        with open(path, errors="replace") as f:
            lines = f.read().split("\n")
    except OSError:
        return set()
    seen = {}
    return {slug(m.group(1), seen) for _, line in outside_code(lines) if (m := re.match(r"^#{1,6} (.+)$", line))}


def problems(path, project):
    """Each problem in one doc, as a short line naming the file."""
    name = os.path.relpath(path, project)
    try:
        with open(path, errors="replace") as f:
            text = f.read()
    except OSError:
        return []
    lines = text.split("\n")
    found = []
    if len(lines) > LONG and not any("contents" in line.lower() for line in lines[:CONTENTS_WITHIN]):
        found.append(f"{name} is {len(lines)} lines with no contents list near the top (docs.md, \"Layout\")")
    for number, line in outside_code(lines):
        for target in re.findall(r"\]\(([^)\s]+)\)", line):
            if re.match(r"^[a-z]+:", target):
                continue
            file_part, _, anchor = target.partition("#")
            linked = os.path.normpath(os.path.join(os.path.dirname(path), file_part)) if file_part else path
            if not os.path.exists(linked):
                found.append(f"{name}:{number} links to {target}, which doesn't exist")
            elif anchor and linked.endswith(".md") and anchor not in anchors(linked):
                found.append(f"{name}:{number} links to {target}, but that heading doesn't exist")
        if name.replace(os.sep, "/").startswith(TBD_FOLDERS) and re.search(r"\bTBD\b", line):
            found.append(f"{name}:{number} says TBD: give a starting value instead (docs.md, \"Specs and plans\")")
    return found


def is_doc(path, project):
    return path.endswith(".md") and path.startswith(os.path.join(project, "docs") + os.sep)


def hook():
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
    if not is_doc(path, project):
        return
    found = problems(path, project)
    if found:
        note = "Docs check: " + "; ".join(found) + ". Fix it in this edit."
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": note}}))


def check_all(project):
    tracked = subprocess.run(["git", "-C", project, "ls-files", "docs"], capture_output=True, text=True).stdout.split("\n")
    found = []
    for name in tracked:
        path = os.path.join(project, name)
        if is_doc(path, project) and os.path.isfile(path):
            found.extend(problems(path, project))
    for line in found:
        print(line)
    return 1 if found else 0


if __name__ == "__main__":
    if "--all" in sys.argv:
        sys.exit(check_all(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
    hook()
