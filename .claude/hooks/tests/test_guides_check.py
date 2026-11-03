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

    def env(self, pages=None, indexes=None):
        pages = pages or {"hooks": "file://" + os.path.join(self.site, "hooks.md")}
        return dict(
            os.environ,
            CLAUDE_PROJECT_DIR=self.project,
            GUIDES_CHECK_PAGES=json.dumps(pages),
            GUIDES_CHECK_INDEXES=json.dumps(indexes or {}),
        )

    def start(self, pages=None, indexes=None):
        data = {"hook_event_name": "SessionStart", "source": "startup"}
        out = subprocess.run(
            [sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=self.env(pages, indexes)
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

    def index(self, *links):
        self.page("llms", "# Docs\n\n" + "".join(f"- [Page](https://docs.test/{link}): about it\n" for link in links))
        return {"index-docs": ["file://" + os.path.join(self.site, "llms.md"), ["https://docs.test/en/"]]}

    def test_a_new_page_in_an_index_is_named(self):
        self.start(indexes=self.index("en/hooks.md"))
        text = self.start(indexes=self.index("en/hooks.md", "en/plugins.md"))
        self.assertIn("index-docs (+1 -0 lines)", text)
        with open(self.guides("diffs", "index-docs.diff")) as f:
            self.assertIn("+https://docs.test/en/plugins.md", f.read())

    def test_index_pages_outside_its_sections_and_new_descriptions_say_nothing(self):
        self.start(indexes=self.index("en/hooks.md"))
        self.page("llms", "- [Hooks guide](https://docs.test/en/hooks.md): new words\n- [X](https://docs.test/api/x.md)\n")
        self.assertEqual(self.start(indexes={"index-docs": [
            "file://" + os.path.join(self.site, "llms.md"), ["https://docs.test/en/"]]}), "")

    def test_an_index_with_no_page_links_is_reported(self):
        indexes = self.index("en/hooks.md")
        self.page("llms", "# Docs moved\n")
        self.assertIn("index-docs has no page links", self.start(indexes=indexes))
        self.assertFalse(os.path.exists(self.guides("reviewed", "index-docs.md")))

    def test_marking_all_reviewed_includes_the_indexes(self):
        self.start(indexes=self.index("en/hooks.md"))
        self.start(indexes=self.index("en/hooks.md", "en/plugins.md"))
        env = self.env(indexes=self.index("en/hooks.md", "en/plugins.md"))
        self.assertTrue(os.path.exists(self.guides("diffs", "index-docs.diff")))
        subprocess.run([sys.executable, HOOK, "--reviewed", "all"], env=env, check=True)
        self.assertFalse(os.path.exists(self.guides("diffs", "index-docs.diff")))


if __name__ == "__main__":
    unittest.main()
