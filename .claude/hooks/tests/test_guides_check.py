#!/usr/bin/env python3
"""Tests for guides-check.py. Run: python3 .claude/hooks/tests/test_guides_check.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "guides-check.py")


class GuidesCheck(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        self.site = tempfile.mkdtemp()
        self.page("hooks", "line one\nline two\n")

    def page(self, name, text):
        with open(os.path.join(self.site, name + ".md"), "w") as f:
            f.write(text)

    def env(self, pages=None):
        pages = pages or {"hooks": "file://" + os.path.join(self.site, "hooks.md")}
        return dict(os.environ, CLAUDE_PROJECT_DIR=self.project, GUIDES_CHECK_PAGES=json.dumps(pages))

    def start(self, pages=None):
        data = {"hook_event_name": "SessionStart", "source": "startup"}
        out = subprocess.run(
            [sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=self.env(pages)
        )
        result = json.loads(out.stdout) if out.stdout.strip() else {}
        return result.get("hookSpecificOutput", {}).get("additionalContext", "")

    def guides(self, *parts):
        return os.path.join(self.project, "work", "guides", *parts)

    def test_the_first_run_saves_the_pages_and_says_nothing(self):
        self.assertEqual(self.start(), "")
        self.assertTrue(os.path.exists(self.guides("reviewed", "hooks.md")))

    def test_an_unchanged_page_says_nothing(self):
        self.start()
        self.assertEqual(self.start(), "")

    def test_a_changed_page_names_its_diff_and_logs_it_once(self):
        self.start()
        self.page("hooks", "line one\nline 2\nline three\n")
        text = self.start()
        self.assertIn("hooks (+2 -1 lines)", text)
        self.assertIn("guides-check", text)
        with open(self.guides("diffs", "hooks.diff")) as f:
            self.assertIn("+line three", f.read())
        self.start()
        with open(self.guides("log.md")) as f:
            self.assertEqual(f.read().count("hooks"), 1)

    def test_marking_it_reviewed_clears_the_note(self):
        self.start()
        self.page("hooks", "new text\n")
        self.start()
        subprocess.run([sys.executable, HOOK, "--reviewed", "hooks"], env=self.env(), check=True)
        self.assertEqual(self.start(), "")
        self.assertFalse(os.path.exists(self.guides("diffs", "hooks.diff")))

    def test_a_page_that_cannot_be_fetched_is_skipped_quietly(self):
        missing = {"hooks": "file://" + os.path.join(self.site, "gone.md")}
        self.assertEqual(self.start(missing), "")
        self.assertFalse(os.path.exists(self.guides("reviewed", "hooks.md")))


if __name__ == "__main__":
    unittest.main()
