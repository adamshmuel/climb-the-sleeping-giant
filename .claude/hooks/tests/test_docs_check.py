#!/usr/bin/env python3
"""Tests for docs-check.py. Run: python3 .claude/hooks/tests/test_docs_check.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "docs-check.py")


class DocsCheck(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()

    def write(self, relative, text):
        path = os.path.join(self.project, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
        return path

    def run_on(self, relative, text):
        path = self.write(relative, text)
        data = {"hook_event_name": "PostToolUse", "tool_name": "Edit", "tool_input": {"file_path": path}}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        return json.loads(out.stdout)["hookSpecificOutput"]["additionalContext"] if out.stdout.strip() else ""

    def test_a_short_clean_doc_says_nothing(self):
        self.assertEqual(self.run_on("docs/ideas/a.md", "# A\n\n## One\n\nSee [one](#one).\n"), "")

    def test_a_long_doc_with_no_contents_list_gets_a_note(self):
        note = self.run_on("docs/design/long.md", "# Long\n" + "x\n" * 120)
        self.assertIn("no contents list", note)

    def test_a_long_doc_with_a_contents_list_says_nothing(self):
        self.assertEqual(self.run_on("docs/design/long.md", "# Long\n\n**Contents**\n" + "x\n" * 120), "")

    def test_a_link_to_a_missing_file_gets_a_note(self):
        note = self.run_on("docs/specs/a.md", "# A\n\nSee [b](b.md).\n")
        self.assertIn("a.md:3 links to b.md, which doesn't exist", note)

    def test_a_link_to_a_missing_heading_gets_a_note(self):
        self.write("docs/specs/b.md", "# B\n\n## Rule 1 (Sprinting is loud)\n")
        self.assertEqual(self.run_on("docs/specs/a.md", "# A\n\n[r](b.md#rule-1-sprinting-is-loud)\n"), "")
        self.assertIn("that heading doesn't exist", self.run_on("docs/specs/a.md", "# A\n\n[r](b.md#rule-2)\n"))

    def test_a_repeated_heading_gets_a_numbered_anchor(self):
        text = "# A\n\n## Notes\n\n## Notes\n\n[second](#notes-1)\n"
        self.assertEqual(self.run_on("docs/plans/a.md", text), "")

    def test_web_links_and_code_blocks_are_skipped(self):
        text = "# A\n\n[guide](https://code.claude.com/docs/en/hooks)\n```\n[x](missing.md) TBD\n```\n"
        self.assertEqual(self.run_on("docs/specs/a.md", text), "")

    def test_tbd_in_a_spec_gets_a_note_but_not_in_a_review(self):
        self.assertIn("says TBD", self.run_on("docs/specs/v2/a.md", "# A\n\nSpeed: TBD\n"))
        self.assertEqual(self.run_on("docs/reviews/a.md", "# A\n\nSpeed: TBD\n"), "")

    def test_a_doc_inside_a_worktree_is_checked(self):
        # Desktop worktree sessions set CLAUDE_PROJECT_DIR to the main checkout.
        self.assertIn("doesn't exist", self.run_on(".claude/worktrees/w1/docs/a.md", "# A\n\n[b](b.md)\n"))

    REMOVED = "# Removed\n\n| Removed piece (the words docs use) | Removed on |\n|---|---|\n| side ladder | 2026-11-03 |\n| `CrossingRamp` | 2026-11-08 |\n"

    def block_on(self, relative, text):
        self.write("docs/removed-pieces.md", self.REMOVED)
        path = self.write(relative, text)
        data = {"hook_event_name": "PostToolUse", "tool_name": "Edit", "tool_input": {"file_path": path}}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        result = json.loads(out.stdout) if out.stdout.strip() else {}
        return result.get("reason", "") if result.get("decision") == "block" else ""

    def test_a_removed_piece_named_as_if_it_exists_is_sent_back(self):
        reason = self.block_on("docs/ideas/a.md", "# A\n\nClimb the Side Ladder to the pad.\n")
        self.assertIn('a.md:3 names "side ladder"', reason)
        self.assertIn("CrossingRamp".lower(), self.block_on("docs/specs/a.md", "# A\n\nWalk over CrossingRamp_Left.\n"))

    def test_a_removed_piece_on_a_line_saying_it_is_gone_passes(self):
        self.assertEqual(self.block_on("docs/ideas/a.md", "# A\n\nThe side ladders were dropped on 2026-11-03.\n"), "")

    def test_history_files_may_name_removed_pieces(self):
        for relative in ("docs/progress/v2/a.md", "docs/specs/v2/research/a.md", "docs/problems-log/a.md", "docs/removed-pieces.md"):
            text = self.REMOVED if relative == "docs/removed-pieces.md" else "# A\n\nClimb the side ladder.\n"
            self.assertEqual(self.block_on(relative, text), "", relative)

    def test_removed_flag_exits_1_on_a_stale_line(self):
        self.write("docs/removed-pieces.md", self.REMOVED)
        self.write("docs/ideas/a.md", "# A\n\nClimb the side ladder.\n")
        subprocess.run(["git", "init", "-q", self.project], check=True)
        subprocess.run(["git", "-C", self.project, "add", "docs"], check=True)
        hooks = os.path.join(self.project, ".claude", "hooks")
        os.makedirs(hooks)
        with open(HOOK) as src, open(os.path.join(hooks, "docs-check.py"), "w") as dst:
            dst.write(src.read())
        out = subprocess.run([sys.executable, os.path.join(hooks, "docs-check.py"), "--removed"], capture_output=True, text=True)
        self.assertEqual(out.returncode, 1)
        self.assertIn("docs/ideas/a.md:3", out.stdout)

    def test_files_outside_docs_are_skipped(self):
        self.assertEqual(self.run_on("work/t5/notes.md", "# A\n\n[b](missing.md)\n" + "x\n" * 120), "")


if __name__ == "__main__":
    unittest.main()
