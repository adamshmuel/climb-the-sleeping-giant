#!/usr/bin/env python3
"""Tests for file-size.py. Run: python3 .claude/hooks/tests/test_file_size.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "file-size.py")


class FileSize(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()

    def run_on(self, relative, lines):
        path = os.path.join(self.project, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("x\n" * lines)
        data = {"hook_event_name": "PostToolUse", "tool_name": "Edit", "tool_input": {"file_path": path}}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        return json.loads(out.stdout) if out.stdout.strip() else {}

    def test_a_short_file_says_nothing(self):
        self.assertEqual(self.run_on("tools/world/route.luau", 900), {})

    def test_a_file_over_900_lines_gets_a_note_to_split_it(self):
        result = self.run_on("tools/world/route.luau", 901)
        text = result["hookSpecificOutput"]["additionalContext"]
        self.assertIn("route.luau is 901 lines", text)
        self.assertNotIn("decision", result)

    def test_a_file_over_1000_lines_is_sent_back(self):
        result = self.run_on("docs/specs/big.md", 1001)
        self.assertEqual(result["decision"], "block")
        self.assertIn("big.md is 1001 lines", result["reason"])

    def test_every_folder_the_rule_covers_is_checked(self):
        for folder in ["src", "tools", "scripts", "docs", ".claude", "work/t5"]:
            self.assertEqual(self.run_on(f"{folder}/a.py", 1001).get("decision"), "block", folder)

    def test_files_outside_those_folders_are_left_alone(self):
        self.assertEqual(self.run_on("references/notes.md", 1500), {})
        self.assertEqual(self.run_on("climb.rbxl", 1500), {})

    def test_a_missing_file_is_left_alone(self):
        data = {"tool_input": {"file_path": os.path.join(self.project, "src", "gone.luau")}}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        self.assertEqual(out.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
