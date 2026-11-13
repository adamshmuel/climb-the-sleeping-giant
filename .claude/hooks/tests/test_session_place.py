#!/usr/bin/env python3
"""Tests for session-place.py. Run: python3 .claude/hooks/tests/test_session_place.py"""

import json
import os
import subprocess
import sys
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "session-place.py")
MAIN = "/Users/kid/Dev/game"
TREE = MAIN + "/.claude/worktrees/happy-tree"


def run(event, cwd, tool="", tool_input=None):
    data = {"hook_event_name": event, "cwd": cwd, "tool_name": tool, "tool_input": tool_input or {}}
    env = {**os.environ, "CLAUDE_PROJECT_DIR": MAIN}
    out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)["hookSpecificOutput"] if out.stdout.strip() else {}


def edit(cwd, path):
    return run("PreToolUse", cwd, "Edit", {"file_path": path}).get("permissionDecision")


def studio(cwd, name):
    return run("PreToolUse", cwd, "mcp__Roblox_Studio__" + name).get("permissionDecision")


class SessionPlace(unittest.TestCase):
    def test_a_worktree_session_is_told_it_is_setup_only(self):
        text = run("SessionStart", TREE)["additionalContext"]
        self.assertIn("setup work only", text)
        self.assertIn(MAIN, text)

    def test_a_worktree_subfolder_still_counts_as_the_worktree(self):
        self.assertIn("setup work only", run("SessionStart", TREE + "/src/server")["additionalContext"])

    def test_the_main_folder_session_is_told_it_is_the_game_session(self):
        self.assertIn("the game session", run("SessionStart", MAIN)["additionalContext"])

    def test_game_code_edits_in_a_worktree_are_refused(self):
        for path in (TREE + "/src/server/Ladders.luau", TREE + "/tools/Build.luau", TREE + "/default.project.json"):
            self.assertEqual(edit(TREE, path), "deny", path)

    def test_game_doc_edits_in_a_worktree_are_refused(self):
        self.assertEqual(edit(TREE, TREE + "/docs/ideas/climb.md"), "deny")
        self.assertEqual(edit(TREE, "docs/plans/v2/x.md"), "deny")

    def test_a_worktree_session_cannot_edit_main_folder_game_files(self):
        self.assertEqual(edit(TREE, MAIN + "/src/client/Hud.luau"), "deny")

    def test_setup_edits_in_a_worktree_pass(self):
        for path in (TREE + "/.claude/hooks/x.py", TREE + "/.claude/rules/git.md", TREE + "/docs/problems-log/a.md"):
            self.assertIsNone(edit(TREE, path), path)

    def test_another_worktrees_files_are_left_alone(self):
        self.assertIsNone(edit(TREE, MAIN + "/.claude/worktrees/other/src/a.luau"))

    def test_the_main_folder_session_edits_game_code(self):
        self.assertIsNone(edit(MAIN, MAIN + "/src/server/Ladders.luau"))

    def test_studio_changes_from_a_worktree_are_refused(self):
        for name in ("execute_luau", "start_stop_play", "multi_edit", "insert_asset", "generate_mesh"):
            self.assertEqual(studio(TREE, name), "deny", name)

    def test_studio_lookups_from_a_worktree_pass(self):
        for name in ("list_roblox_studios", "script_read", "get_console_output", "search_game_tree"):
            self.assertIsNone(studio(TREE, name), name)

    def test_the_main_folder_session_uses_studio(self):
        self.assertIsNone(studio(MAIN, "execute_luau"))

    def test_starting_a_session_gets_the_reminder_everywhere(self):
        for cwd in (MAIN, TREE):
            out = run("PreToolUse", cwd, "mcp__ccd_session__start_session")
            self.assertIn("main-folder session", out["additionalContext"])
            self.assertNotIn("permissionDecision", out)

    def test_bad_input_prints_nothing(self):
        out = subprocess.run([sys.executable, HOOK], input="not json", capture_output=True, text=True)
        self.assertEqual((out.returncode, out.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
