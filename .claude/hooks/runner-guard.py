#!/usr/bin/env python3
"""PreToolUse hook for the runner only (the hooks: block in runner.md).

The runner runs jobs others wrote and never changes the game's code, the
tools or the rules that hold it (runner.md). Its shell only reads and runs
the job check; it writes only in work/, with Write/Edit, so no redirections.
The sub-agents guide scopes a hook to one agent in its frontmatter, so this
lives here instead of in the hook every agent runs (2026-11-03).
"""

import json
import os
import re
import shlex
import sys

RUNNER_SHELL = {"cd", "ls", "cat", "head", "tail", "grep", "wc", "date", "pwd", "echo", "scripts/job-check.sh", "./scripts/job-check.sh"}
RUNNER_GIT = {"status", "diff", "log", "show"}
RUNNER_GIT_FLAGS = {"--stat", "--oneline", "--name-only", "--name-status", "--short", "-s", "--porcelain", "--no-color", "-n", "--"}


def git_word_ok(w):
    # Refs and paths are fine; a flag must be on the list, since some
    # (git diff --output=x) write files.
    if not w.startswith("-"):
        return True
    return w in RUNNER_GIT_FLAGS or re.fullmatch(r"-n?[0-9]+", w) is not None


def shell_ok(command):
    # The full run's wait (writing-handoffs skill, "Models"), exactly as written there.
    wait = re.fullmatch(r'python3 -c "import time; time\.sleep\(([0-9]{1,3})\)"', command.strip())
    if wait:
        return int(wait.group(1)) <= 120
    # A new line runs a second command in bash, but shlex reads it as a space.
    if "\n" in command or "\r" in command:
        return False
    # Checked on the raw text, so no quoting or # can hide them.
    if any(s in command for s in ("$(", "`", "${", "<(", ">(")):
        return False
    # Merging error output into the normal output writes no file.
    command = command.replace("2>&1", " ")
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        lexer.commenters = ""
        words = list(lexer)
    except ValueError:
        return False
    first = True
    git = 0
    for w in words:
        if w in ("&&", ";", "|", "||"):
            first, git = True, 0
            continue
        if set(w) <= set("<>&|;()"):
            return False
        if first:
            if w == "git":
                git = 1
            elif w not in RUNNER_SHELL:
                return False
            first = False
        elif git == 1:
            if w not in RUNNER_GIT:
                return False
            git = 2
        elif git == 2 and not git_word_ok(w):
            return False
    return True


def write_ok(raw, base):
    # Only notes and tables in work/; everything else is out of the runner's job.
    if os.path.islink(os.path.join(base, os.path.expanduser(raw))):
        return False
    full = os.path.realpath(os.path.join(base, os.path.expanduser(raw))).lower()
    work = os.path.realpath(os.path.join(base, "work")).lower()
    return full.startswith(work + os.sep)


def refusal(data):
    tool = data.get("tool_name")
    inp = data.get("tool_input") or {}
    base = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        raw = inp.get("file_path") or inp.get("notebook_path") or ""
        if not raw or not write_ok(raw, base):
            return "The runner writes only in work/ (runner.md). Report anything else as a question instead."
    if tool == "Bash" and not shell_ok(inp.get("command") or ""):
        return (
            "The runner's shell only reads and runs scripts/job-check.sh "
            "(cd, ls, cat, head, tail, grep, wc, date, pwd, echo, git status/diff/log/show), "
            "with no redirections. Write notes with Write. Report anything else as a question."
        )
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        print("runner-guard: hook input was not JSON", file=sys.stderr)
        return
    reason = refusal(data)
    if reason:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))


if __name__ == "__main__":
    main()
