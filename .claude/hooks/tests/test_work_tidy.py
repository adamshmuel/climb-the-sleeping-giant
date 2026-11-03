#!/usr/bin/env python3
"""Tests for work-tidy.py. Run: python3 .claude/hooks/tests/test_work_tidy.py"""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "work-tidy.py")
OLD = time.time() - 10 * 86400


class WorkTidy(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        self.trash = tempfile.mkdtemp()
        subprocess.run(["git", "init", "-q", self.project], check=True)

    def make(self, rel, old=False, text="x\n"):
        path = os.path.join(self.project, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
        if old:
            os.utime(path, (OLD, OLD))
        return path

    def run_hook(self, data):
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project, WORK_TIDY_TRASH=self.trash)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        return json.loads(out.stdout) if out.stdout.strip() else {}

    def start(self):
        return self.run_hook({"hook_event_name": "SessionStart", "source": "startup"})

    def in_trash(self, rel):
        return any(os.path.exists(os.path.join(self.trash, d, rel)) for d in os.listdir(self.trash))

    def test_an_old_task_folder_goes_to_the_trash(self):
        self.make("work/t9/notes.md", old=True)
        result = self.start()
        self.assertFalse(os.path.exists(os.path.join(self.project, "work", "t9")))
        self.assertTrue(self.in_trash("t9/notes.md"))
        self.assertIn("moved 1 work/ files", result["hookSpecificOutput"]["additionalContext"])

    def test_a_folder_with_one_recent_file_stays_whole(self):
        self.make("work/t9/old.md", old=True)
        self.make("work/t9/new.md")
        self.assertEqual(self.start(), {})
        self.assertTrue(os.path.exists(os.path.join(self.project, "work", "t9", "old.md")))

    def test_kept_folders_stay_even_when_old(self):
        self.make("work/guides/log.md", old=True)
        self.make("work/place-backups/a.rbxl", old=True)
        self.assertEqual(self.start(), {})

    def test_a_file_a_git_file_names_stays(self):
        self.make("work/t9/ruling.md", old=True)
        self.make("work/t9/scratch.py", old=True)
        self.make("docs/plan.md", text="See work/t9/ruling.md.\n")
        subprocess.run(["git", "-C", self.project, "add", "docs/plan.md"], check=True)
        self.start()
        self.assertTrue(os.path.exists(os.path.join(self.project, "work", "t9", "ruling.md")))
        self.assertTrue(self.in_trash("t9/scratch.py"))

    def test_an_old_loose_file_goes_too(self):
        self.make("work/e3.py", old=True)
        self.start()
        self.assertTrue(self.in_trash("e3.py"))

    def test_a_loose_new_file_gets_a_note(self):
        path = self.make("work/report.md")
        result = self.run_hook({"hook_event_name": "PostToolUse", "tool_input": {"file_path": path}})
        self.assertIn("loose in work/", result["hookSpecificOutput"]["additionalContext"])

    def test_a_file_in_a_task_folder_gets_no_note(self):
        path = self.make("work/t9/report.md")
        self.assertEqual(self.run_hook({"hook_event_name": "PostToolUse", "tool_input": {"file_path": path}}), {})


if __name__ == "__main__":
    unittest.main()
