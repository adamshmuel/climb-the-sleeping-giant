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
- Edit/Write of setup text (CLAUDE.md, rules, agents, skills, commands): warns
  when a new line nearly repeats a line in another of those files, so the
  copy becomes a pointer to the rule's one home (the memory guide: no
  duplicates). A warning, not a block: a home moving its own text is fine.
- Bash that writes a setup file (>, tee, sed -i, mv, cp or ln into it,
  git mv, or a Python script that writes one): blocked, so every setup change
  goes through Edit/Write and the check above. Every target is resolved
  against any `cd` before it. rm and git rm of rule, skill or agent text only
  get the reminder (deleting can't make a file longer); of a hook or settings
  file they are blocked, because that turns a guard off.
Written rules kept being missed; the memory guide says a rule Claude must
follow every time belongs in a hook (2026-11-03).
"""

import json
import os
import re
import shlex
import sys

MEMORY = "https://code.claude.com/docs/en/memory"
# An agent's prompt follows its model's prompting guide too; guides-check.py watches the same pages.
MODEL_GUIDES = "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-{opus,sonnet,haiku}-5-5"
GUIDES = [
    (re.compile(r"(^|/)CLAUDE(\.local)?\.md$"), MEMORY, 200),
    (re.compile(r"(^|/)\.claude/rules/.+\.md$"), MEMORY, 200),
    (re.compile(r"(^|/)\.claude/skills/.+/SKILL\.md$"), "https://code.claude.com/docs/en/skills", 500),
    (re.compile(r"(^|/)\.claude/skills/"), "https://code.claude.com/docs/en/skills", None),
    (re.compile(r"(^|/)\.claude/agents/"), f"https://code.claude.com/docs/en/sub-agents and the agent's model page {MODEL_GUIDES}", None),
    (re.compile(r"(^|/)\.claude/agent-memory/"), "https://code.claude.com/docs/en/sub-agents (persistent memory)", None),
    (re.compile(r"(^|/)\.claude/hooks/"), "https://code.claude.com/docs/en/hooks", None),
    (re.compile(r"(^|/)\.claude/commands/"), "https://code.claude.com/docs/en/skills", None),
    (re.compile(r"(^|/)\.claude/settings(\.local)?\.json$"), "https://code.claude.com/docs/en/settings", None),
]
BEST = "https://code.claude.com/docs/en/best-practices"
SETUP = r"CLAUDE(\.local)?\.md|\.claude/(rules|agents|skills|hooks|commands|settings)"
# Case-blind, because the Mac's disk is: `claude.md` is the same file as `CLAUDE.md`.
SETUP_IN_SHELL = re.compile(SETUP, re.I)
# Deleting these turns a guard off, so it is blocked, not only reminded.
PROTECTED = re.compile(r"\.claude/(hooks|settings)", re.I)
# A redirect counts only when it points at a setup file, so `2>/dev/null` or a copy into work/ still reads.
REDIRECT = re.compile(r">{1,2}\s*[\"']?([^\s;&|\"']+)")
SCRIPT_FLAGS = {"-e", "-f", "--expression", "--file"}
TARGET_FLAGS = {"-t", "--target-directory"}
# A Python script that opens a file to write, or copies, moves or writes one.
PYTHON = re.compile(r"\bpython3?\b")
# A quoted w, a or x is a write mode only inside open() (any open: built-in, Path, io, codecs), even across
# lines; alone it is a test filter or a count. A read that only looks like a write is blocked: fail closed.
PYTHON_WRITES = re.compile(
    r"""open\((.*?,\s*)?(mode\s*=\s*)?['"][wax]b?\+?['"]|O_(WRONLY|RDWR|APPEND|CREAT|TRUNC)|write_text|write_bytes"""
    r"""|shutil\.(copy\w*|move|rmtree)|os\.(rename|replace|remove|unlink)""",
    re.S,
)
SEGMENTS = re.compile(r"&&|\|\||[;|\n]")
# Commands where every file named is changed (mv also removes its source), and where only the last one is.
# rm is not here: deleting can't make a file longer, so it only gets the guide reminder.
CHANGES_EVERY_FILE = {"mv", "truncate", "tee"}
CHANGES_LAST_FILE = {"cp", "ln", "install", "rsync"}
IN_PLACE = re.compile(r"^(-[a-zA-Z]*i|--in-place)")
# The reminder is for setup talk only, so game prompts stay short.
# A copied rule: most of a new line's words already stand in one line of another setup text file.
SETUP_TEXT = re.compile(r"(^|/)(CLAUDE(\.local)?\.md|\.claude/(rules|agents|skills|commands)/.+\.md)$")
WORD = re.compile(r"[a-z0-9_]{3,}")
COMMON = {
    "the", "and", "for", "with", "that", "this", "from", "into", "its", "are", "not", "never", "only", "every",
    "one", "each", "when", "before", "after", "your", "you", "them", "than", "then", "what", "which", "all",
    "any", "but", "has", "have", "was", "use", "add",
}  # fmt: skip
# A pointer ("Follow `luau.md`") has too few words to count; a copy shares at least 3 in 4 of the longer line's,
# so a short line that only borrows a few words from a long one is not a copy.
MIN_WORDS = 6
SAME = 0.75
# Frontmatter (tools:, skills:, model:) repeats across agent files on purpose.
FRONTMATTER = re.compile(r"^[\w-]+:(\s|$)")
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


def words(line):
    if FRONTMATTER.match(line):
        return set()
    return {w.rstrip("s") for w in WORD.findall(line.lower()) if w not in COMMON}


def setup_texts(skip):
    root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    paths = [os.path.join(root, "CLAUDE.md")]
    for top in ("rules", "agents", "skills", "commands"):
        for folder, _, names in os.walk(os.path.join(root, ".claude", top)):
            paths += [os.path.join(folder, n) for n in names if n.endswith(".md")]
    for p in paths:
        text = None if os.path.realpath(p) == os.path.realpath(skip) else read_lines(p)
        if text:
            yield os.path.relpath(p, root).replace(os.sep, "/"), text


def duplicates(path, old, after):
    """Lines of other setup text files that a line this change adds nearly repeats, as `file:line`."""
    known = set((old or "").splitlines())
    added = [w for w in (words(line) for line in after.splitlines() if line not in known) if len(w) >= MIN_WORDS]
    found = []
    if not added:
        return found
    for rel, text in setup_texts(path):
        for n, line in enumerate(text.splitlines(), 1):
            have = words(line)
            if len(have) >= MIN_WORDS and any(len(w & have) >= SAME * max(len(w), len(have)) for w in added):
                found.append(f"{rel}:{n}")
    return found


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
    note = (
        f"Setup file. Check Anthropic's guide ({url}, and {BEST}) before this change, "
        "and say in your report which guide point it follows."
    )
    copies = duplicates(path, old, after) if after is not None and SETUP_TEXT.search(path.replace(os.sep, "/")) else []
    if copies:
        note += (
            f" New lines nearly repeat {', '.join(copies[:5])}. Each rule has one home ({MEMORY}: no duplicates): "
            "point to that home in one line, or move the rule there, instead of keeping two copies."
        )
    emit("PreToolUse", additionalContext=note)


def sed_files(args):
    """The files sed or perl edits: never the script text, given with -e or as the first word."""
    files, script_given, skip = [], False, False
    for a in args:
        if skip:
            skip = False
        elif a in SCRIPT_FLAGS:
            script_given = skip = True
        elif a and not a.startswith("-"):
            files.append(a)
    return files if script_given else files[1:]


def written_files(cmd, args):
    files = [a for a in args if a and not a.startswith("-")]
    if cmd in CHANGES_EVERY_FILE:
        return files
    if cmd in CHANGES_LAST_FILE:
        for i, a in enumerate(args[:-1]):
            if a in TARGET_FLAGS:
                return [args[i + 1]]
        return files[-1:]
    if cmd in ("sed", "perl") and any(IN_PLACE.match(a) for a in args):
        return sed_files(args)
    return []


def shell_targets(command):
    """Return (written, deleted) paths, each resolved against any `cd` before it."""
    written, deleted, cwd = [], [], ""
    for segment in SEGMENTS.split(command):
        try:
            words = shlex.split(segment)
        except ValueError:
            words = segment.split()
        if not words:
            continue
        cmd, args = os.path.basename(words[0]), words[1:]
        if cmd == "git" and args[:1] in (["mv"], ["rm"]):
            cmd, args = args[0], args[1:]
        if cmd == "cd" and args:
            cwd = os.path.normpath(os.path.join(cwd, args[0]))
            continue
        here = lambda p: os.path.normpath(os.path.join(cwd, p)) if cwd else p  # noqa: E731
        written += [here(p) for p in REDIRECT.findall(segment)]
        written += [here(p) for p in written_files(cmd, args)]
        if cmd == "rm":
            deleted += [here(a) for a in args if a and not a.startswith("-")]
    return written, deleted


def check_shell(command):
    written, deleted = shell_targets(command)
    python_write = PYTHON.search(command) and SETUP_IN_SHELL.search(command) and PYTHON_WRITES.search(command)
    if python_write or any(SETUP_IN_SHELL.search(p) for p in written):
        emit(
            "PreToolUse",
            permissionDecision="deny",
            permissionDecisionReason=(
                "This shell command writes a setup file (CLAUDE.md, .claude/rules, agents, skills, hooks or "
                "settings). Make setup changes with Edit or Write, so the guide check in "
                ".claude/hooks/setup-guides.py runs on them."
            ),
        )
    elif any(PROTECTED.search(p) for p in deleted):
        emit(
            "PreToolUse",
            permissionDecision="deny",
            permissionDecisionReason=(
                "Deleting a hook or settings file turns a guard off. Empty its entry in .claude/settings.json "
                "with Edit first, or ask the user."
            ),
        )
    elif any(SETUP_IN_SHELL.search(p) for p in deleted):
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
