#!/usr/bin/env python3
"""PreToolUse hook (Bash): enforce the git rules in .claude/rules/git.md.

Blocks staging everything, commit -a, push, --amend, rebase, reset --hard,
git clean, any history change from a subagent (only the main chat commits),
and AI attribution in a commit. Warns when a commit title is over 50 characters.
"""

import json
import re
import shlex
import sys

SEPARATORS = {";", "&&", "||", "|", "&", "(", ")"}
GIT_VALUE_FLAGS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
ALL_PATHS = {"-A", "--all", ".", "-u", "--update", ":/", "*"}
COMMIT_VALUE_FLAGS = {"-m", "--message", "-F", "--file", "-C", "-c", "--author", "--date", "-t", "--template"}
AGENT_BLOCKED = {"commit", "merge", "push", "rebase", "reset", "cherry-pick", "revert", "am", "tag"}
# "Claude" as a name, never inside CLAUDE.md or a .claude/ path.
ATTRIBUTION = re.compile(
    r"co-authored-by|generated with|(?<![./\w])claude(?![.\w/-])|anthropic|\bAI\b",
    re.IGNORECASE,
)
TITLE_MAX = 50


def words_of(command):
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        lexer.commenters = ""
        return list(lexer)
    except ValueError:
        return command.split()


def git_commands(words):
    """Yield (subcommand, args) for each git command in the line."""
    start = True
    i = 0
    while i < len(words):
        w = words[i]
        if w in SEPARATORS:
            start = True
            i += 1
            continue
        if start and w == "git":
            j = i + 1
            while j < len(words) and words[j].startswith("-"):
                j += 2 if words[j] in GIT_VALUE_FLAGS else 1
            k = j + 1
            while k < len(words) and words[k] not in SEPARATORS:
                k += 1
            if j < len(words) and words[j] not in SEPARATORS:
                yield words[j], words[j + 1 : k]
            i = k
            continue
        start = False
        i += 1


def commit_parts(args):
    """Return (stages_all, messages) for git commit's arguments."""
    stages_all = False
    messages = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--all":
            stages_all = True
        elif a in COMMIT_VALUE_FLAGS:
            if a in ("-m", "--message") and i + 1 < len(args):
                messages.append(args[i + 1])
            i += 1
        elif re.fullmatch(r"-[a-zA-Z]+", a):
            if "a" in a[1:]:
                stages_all = True
            if a.endswith("m") and i + 1 < len(args):
                messages.append(args[i + 1])
                i += 1
        i += 1
    return stages_all, messages


def check(command, from_agent):
    """Return (deny_reason, warning)."""
    warning = None
    for sub, args in git_commands(words_of(command)):
        if from_agent and sub in AGENT_BLOCKED:
            return f"Only the main chat runs `git {sub}` (git.md, \"Commits\"). Report the change instead.", None
        if sub == "add" and ALL_PATHS & set(args):
            return "Stage files by name (`git add <path> ...`), never everything (git.md, \"Commits\").", None
        if sub == "push":
            return "Only Adam pushes (git.md, \"Never\"). Tell him it's ready to push.", None
        if sub == "rebase" or (sub == "commit" and "--amend" in args) or (sub == "reset" and "--hard" in args):
            return "Never rewrite existing commits: no rebase, --amend or reset --hard (git.md, \"Never\").", None
        if sub == "clean":
            return "`git clean` can delete the untracked work/ folder. Remove files by name instead.", None
        if sub == "commit":
            stages_all, messages = commit_parts(args)
            if stages_all:
                return "Stage files by name, never with commit -a (git.md, \"Commits\").", None
            if ATTRIBUTION.search(command.replace("CLAUDE.md", "")):
                return "No AI attribution or AI mention in commits (git.md, \"No AI attribution\"). Remove it and commit again.", None
            if messages and len(messages[0].splitlines()[0]) > TITLE_MAX:
                warning = f"The commit title is over {TITLE_MAX} characters (git.md, \"Commits\"). Shorten it next time."
    return None, warning


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        print("git-guard: hook input was not JSON", file=sys.stderr)
        return
    command = (data.get("tool_input") or {}).get("command") or ""
    if "git" not in command:
        return
    reason, warning = check(command, bool(data.get("agent_id")))
    if reason:
        out = {"permissionDecision": "deny", "permissionDecisionReason": reason}
    elif warning:
        out = {"additionalContext": warning}
    else:
        return
    out["hookEventName"] = "PreToolUse"
    print(json.dumps({"hookSpecificOutput": out}))


if __name__ == "__main__":
    main()
