#!/usr/bin/env python3
"""Keep game work in the one main-folder session, and worktree sessions on setup work.

Why: Studio, Rojo (port 34873) and the world are tied to the main folder. On 2026-11-04 two
sessions ran in a worktree, the app blocked their agents from the main folder, and Task 6d
stalled. Anthropic's guides: worktree is off by default and is for separate work whose edits
must not collide (https://code.claude.com/docs/en/desktop.md#run-a-session-in-its-own-worktree,
https://code.claude.com/docs/en/best-practices.md "Run sessions in parallel").

A worktree session is told so at start, and is refused:
- edits to the game's files (src/, tools/, docs/specs, docs/plans, docs/ideas, docs/design,
  docs/reviews, docs/progress, default.project.json), since Rojo never syncs them from there;
- Roblox Studio tools that change or play the game (read-only lookups still pass).
Every session that starts another one is reminded where game work goes.
The worktree is found from the hook's `cwd` (https://code.claude.com/docs/en/worktrees.md,
"What worktrees share with the main checkout"): in a desktop worktree session hooks run in
the main folder, so CLAUDE_PROJECT_DIR can't tell.
"""

import json
import os
import sys

MARK = os.sep + os.path.join(".claude", "worktrees") + os.sep
GAME_PATHS = (
    "src/",
    "tools/",
    "docs/specs/",
    "docs/plans/",
    "docs/ideas/",
    "docs/design/",
    "docs/reviews/",
    "docs/progress/",
    "default.project.json",
)
STUDIO = "mcp__Roblox_Studio__"
STUDIO_READ_ONLY = {
    "list_roblox_studios",
    "get_studio_state",
    "script_read",
    "script_grep",
    "script_search",
    "search_game_tree",
    "inspect_instance",
    "get_console_output",
    "list_skills",
    "skill",
    "search_asset",
}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
RULE = "`.claude/rules/agent-workflow.md`, \"Sessions\""


def worktree_root(cwd):
    """The worktree folder holding cwd, or None in the main folder."""
    if not cwd or MARK not in cwd + os.sep:
        return None
    head, tail = (cwd + os.sep).split(MARK, 1)
    return os.path.join(head + MARK.rstrip(os.sep), tail.split(os.sep, 1)[0])


def main_folder(root):
    return root.split(MARK, 1)[0]


def output(event, **fields):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": event, **fields}}))


def deny(reason):
    output("PreToolUse", permissionDecision="deny", permissionDecisionReason=reason)


def game_file(path, root):
    if not path:
        return False
    full = os.path.normpath(path if os.path.isabs(path) else os.path.join(root, path))
    if full.startswith(root + os.sep):
        rel = full[len(root) + 1 :]
    elif MARK in full:
        return False  # another worktree's file is that session's business
    elif full.startswith(main_folder(root) + os.sep):
        rel = full[len(main_folder(root)) + 1 :]
    else:
        return False
    return rel.startswith(GAME_PATHS)


def session_start(root):
    if root:
        output(
            "SessionStart",
            additionalContext=(
                f"This session runs in the worktree {root}, not the main folder. Worktree sessions do "
                f"setup work only (hooks, rules, skills, agents, settings) on a setup/ branch ({RULE}). "
                "Game work (src/, tools/, game docs, Studio, Rojo) belongs to the one main-folder "
                f"session in {main_folder(root)}: if asked for it here, message that session or start "
                "one there with worktree off, and tell the user."
            ),
        )
    else:
        output(
            "SessionStart",
            additionalContext=(
                f"This is the main-folder session: the game session. Only one runs at a time ({RULE}). "
                "Setup work that never touches Studio may run in a worktree session on a setup/ branch."
            ),
        )


def pre_tool_use(data, root):
    tool = data.get("tool_name") or ""
    tool_input = data.get("tool_input") or {}
    if tool == "mcp__ccd_session__start_session":
        output(
            "PreToolUse",
            additionalContext=(
                f"Sessions ({RULE}): game work goes to the one main-folder session, never a second one "
                "and never a worktree (message the game session if one runs). A new setup session "
                "uses its own worktree and a setup/ branch."
            ),
        )
        return
    if not root:
        return
    if tool in EDIT_TOOLS:
        path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
        if game_file(path, root):
            deny(
                f"{path} is a game file, and this is a worktree session ({RULE}). Rojo serves the main "
                "folder, so the edit would never reach Studio. Hand it to the main-folder game session "
                "(SendMessage to it, or save a patch in work/ and tell it), and tell the user."
            )
        return
    if tool.startswith(STUDIO) and tool[len(STUDIO) :] not in STUDIO_READ_ONLY:
        deny(
            f"{tool} changes or plays the game, and this is a worktree session ({RULE}). Studio runs "
            "the main folder's code. Hand the job to the main-folder game session, and tell the user."
        )


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if not isinstance(data, dict):
        return
    root = worktree_root(data.get("cwd") or "")
    event = data.get("hook_event_name")
    if event == "SessionStart":
        session_start(root)
    elif event == "PreToolUse":
        pre_tool_use(data, root)


if __name__ == "__main__":
    main()
