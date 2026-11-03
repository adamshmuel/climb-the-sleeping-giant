#!/usr/bin/env python3
"""Keep the agent setup in line with Anthropic's official guides (CLAUDE.md, "Follow Anthropic's guides").

Setup files are CLAUDE.md, .claude/rules, .claude/agents, .claude/skills,
.claude/hooks, .claude/commands and .claude/settings*.json.
- UserPromptSubmit: when the prompt talks about the setup, reminds the main
  chat to check the guides before taking up any suggestion, the user's own included.
- Edit/Write on a setup file: names the guide page to check. Blocks a change
  that leaves CLAUDE.md or a rule file over 200 lines, or a SKILL.md over
  500, and makes it longer (the guides' size targets: long files are followed
  less). Shrinking a file already over the line is always allowed.
- Bash that writes a setup file (>, tee, sed -i, mv, cp or ln into it,
  git mv, or a Python script that writes one): blocked, so every setup change
  goes through Edit/Write and the check above. rm and git rm only get the
  reminder, because deleting can't make a file longer.
Written rules kept being missed; the memory guide says a rule Claude must
follow every time belongs in a hook (2026-11-03).
"""

import json
import os
import re
import shlex
import sys

MEMORY = "https://code.claude.com/docs/en/memory"
GUIDES = [
    (re.compile(r"(^|/)CLAUDE(\.local)?\.md$"), MEMORY, 200),
    (re.compile(r"(^|/)\.claude/rules/.+\.md$"), MEMORY, 200),
    (re.compile(r"(^|/)\.claude/skills/.+/SKILL\.md$"), "https://code.claude.com/docs/en/skills", 500),
    (re.compile(r"(^|/)\.claude/skills/"), "https://code.claude.com/docs/en/skills", None),
    (re.compile(r"(^|/)\.claude/agents/"), "https://code.claude.com/docs/en/sub-agents", None),
    (re.compile(r"(^|/)\.claude/hooks/"), "https://code.claude.com/docs/en/hooks", None),
    (re.compile(r"(^|/)\.claude/commands/"), "https://code.claude.com/docs/en/skills", None),
    (re.compile(r"(^|/)\.claude/settings(\.local)?\.json$"), "https://code.claude.com/docs/en/settings", None),
]
BEST = "https://code.claude.com/docs/en/best-practices"
SETUP = r"CLAUDE(\.local)?\.md|\.claude/(rules|agents|skills|hooks|commands|settings)"
# Case-blind, because the Mac's disk is: `claude.md` is the same file as `CLAUDE.md`.
SETUP_IN_SHELL = re.compile(SETUP, re.I)
# A redirect counts only when it points at a setup file, so `2>/dev/null` or a copy into work/ still reads.
REDIRECT_TO_SETUP = re.compile(r">{1,2}\s*[\"']?[^\s;&|]*(" + SETUP + ")", re.I)
# A Python script that opens a file to write, or copies, moves or writes one.
PYTHON = re.compile(r"\bpython3?\b")
PYTHON_WRITES = re.compile(r"""['"][wax]b?\+?['"]|write_text|write_bytes|shutil\.(copy|move)|os\.(rename|replace|remove)""")
SEGMENTS = re.compile(r"&&|\|\||[;|\n]")
# Commands where every file named is changed (mv also removes its source), and where only the last one is.
# rm is not here: deleting can't make a file longer, so it only gets the guide reminder.
CHANGES_EVERY_FILE = {"mv", "truncate", "tee"}
CHANGES_LAST_FILE = {"cp", "ln", "install", "rsync"}
IN_PLACE = re.compile(r"^(-[a-zA-Z]*i|--in-place)")
# The reminder is for setup talk only, so game prompts stay short.
SETUP_WORDS = re.compile(r"\b(rules?|agents?|subagents?|skills?|hooks?|claude\.md|settings?|workflow|setup|memory|guides?)\b", re.I)

PROMPT_NOTE = (
    "Before taking up any suggestion about the agent setup (CLAUDE.md, rules, agents, skills, hooks, "
    "settings, the workflow), the user's own included: check Anthropic's official guide for it "
    f"({BEST} and the page for that kind of file) and say in one line whether it fits the guide, "
    "or what the guide does better, with the link. CLAUDE.md, \"Follow Anthropic's guides\"."
)


def emit(event, **fields):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": event, **fields}}))


def guide_for(path):
    for pattern, url, limit in GUIDES:
        if pattern.search(path):
            return url, limit
    return None


def read_lines(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return None


def new_text(tool, tool_input, old):
    if tool == "Write":
        return tool_input.get("content", "")
    if old is None:
        return None
    edits = tool_input.get("edits") or [tool_input]
    text = old
    for e in edits:
        a, b = e.get("old_string", ""), e.get("new_string", "")
        if not a or a not in text:
            return None
        text = text.replace(a, b) if e.get("replace_all") else text.replace(a, b, 1)
    return text


def count(text):
    return len(text.splitlines()) if text else 0


def check_file(tool, tool_input):
    path = tool_input.get("file_path", "")
    found = guide_for(path.replace(os.sep, "/"))
    if not found:
        return
    url, limit = found
    old = read_lines(path)
    after = new_text(tool, tool_input, old)
    if limit and after is not None:
        before, lines = count(old), count(after)
        if lines > limit and lines > before:
            emit(
                "PreToolUse",
                permissionDecision="deny",
                permissionDecisionReason=(
                    f"{os.path.basename(path)} would be {lines} lines (was {before}). Anthropic's guide ({url}) "
                    f"targets under {limit}: long files are followed less. Shorten it, or move the part that "
                    "isn't needed every time into a skill or a path-scoped rule, then make this change."
                ),
            )
            return
    emit(
        "PreToolUse",
        additionalContext=(
            f"Setup file. Check Anthropic's guide ({url}, and {BEST}) before this change, "
            "and say in your report which guide point it follows."
        ),
    )


def segment_writes_setup(segment):
    try:
        words = shlex.split(segment)
    except ValueError:
        words = segment.split()
    if not words:
        return False
    cmd, args = os.path.basename(words[0]), words[1:]
    files = [a for a in args if not a.startswith("-")]
    if cmd == "git" and files[:1] in (["mv"], ["rm"]):
        cmd, files = files[0], files[1:]
    if cmd in CHANGES_EVERY_FILE:
        return any(SETUP_IN_SHELL.search(f) for f in files)
    if cmd in CHANGES_LAST_FILE:
        return bool(files) and bool(SETUP_IN_SHELL.search(files[-1]))
    if cmd in ("sed", "perl") and any(IN_PLACE.match(a) for a in args):
        return any(SETUP_IN_SHELL.search(f) for f in files)
    return False


def segment_deletes_setup(segment):
    words = segment.split()
    if words[:2] == ["git", "rm"]:
        words = words[1:]
    return bool(words) and os.path.basename(words[0]) == "rm" and any(SETUP_IN_SHELL.search(w) for w in words[1:])


def check_shell(command):
    python_write = PYTHON.search(command) and SETUP_IN_SHELL.search(command) and PYTHON_WRITES.search(command)
    if python_write or REDIRECT_TO_SETUP.search(command) or any(segment_writes_setup(s) for s in SEGMENTS.split(command)):
        emit(
            "PreToolUse",
            permissionDecision="deny",
            permissionDecisionReason=(
                "This shell command writes a setup file (CLAUDE.md, .claude/rules, agents, skills, hooks or "
                "settings). Make setup changes with Edit or Write, so the guide check in "
                ".claude/hooks/setup-guides.py runs on them."
            ),
        )
    elif any(segment_deletes_setup(s) for s in SEGMENTS.split(command)):
        emit(
            "PreToolUse",
            additionalContext=(
                f"Deleting a setup file. Check Anthropic's guide ({BEST}) and update every pointer to it, "
                "and say in your report which guide point the change follows."
            ),
        )


def main():
    try:
        data = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    event = data.get("hook_event_name")
    if event == "UserPromptSubmit":
        if SETUP_WORDS.search(data.get("prompt", "")):
            emit("UserPromptSubmit", additionalContext=PROMPT_NOTE)
    elif event == "PreToolUse":
        tool = data.get("tool_name")
        tool_input = data.get("tool_input") or {}
        if tool in ("Edit", "Write", "MultiEdit"):
            check_file(tool, tool_input)
        elif tool == "Bash":
            check_shell(tool_input.get("command", ""))


if __name__ == "__main__":
    main()
