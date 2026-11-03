#!/usr/bin/env python3
"""Tests for job-check-hook.py. Run: python3 .claude/hooks/tests/test_job_check_hook.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "job-check-hook.py")
# The fake checker fails when the file says FAIL, and prints the arguments it got.
FAKE = '#!/usr/bin/env bash\necho "args: $*"\nif grep -q FAIL "${@: -1}"; then echo "Job check FAILED: bad step"; exit 1; fi\n'


class JobCheckHook(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, "scripts"))
        os.makedirs(os.path.join(self.project, "work", "t5"))
        os.makedirs(os.path.join(self.project, "src"))
        fake = os.path.join(self.project, "scripts", "job-check.sh")
        with open(fake, "w") as f:
            f.write(FAKE)
        os.chmod(fake, 0o755)

    def run_on(self, relative, text):
        path = os.path.join(self.project, relative)
        with open(path, "w") as f:
            f.write(text)
        data = {"hook_event_name": "PostToolUse", "tool_name": "Write", "tool_input": {"file_path": path}}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        return json.loads(out.stdout) if out.stdout.strip() else {}

    def test_a_failing_handoff_sends_the_failure_back(self):
        result = self.run_on("work/t5/handoff.md", "## Step 1 FAIL\n")
        self.assertEqual(result.get("decision"), "block")
        self.assertIn("bad step", result["reason"])
        self.assertIn("--handoff", result["reason"])

    def test_a_card_over_800_words_is_sent_back(self):
        result = self.run_on("work/t5/card.md", "word " * 801)
        self.assertEqual(result.get("decision"), "block")
        self.assertIn("800", result["reason"])

    def test_a_short_passing_card_is_quiet(self):
        self.assertEqual(self.run_on("work/t5/card.md", "## Step 1\nStands on: nothing\n"), {})

    def test_a_job_script_is_checked_as_a_job(self):
        result = self.run_on("work/t5/server.luau", "-- FAIL\n")
        self.assertIn("bad step", result["reason"])
        self.assertNotIn("--handoff", result["reason"])

    def test_a_checker_that_cannot_run_is_reported(self):
        # A missing or broken job-check.sh must not let a card through unchecked.
        os.remove(os.path.join(self.project, "scripts", "job-check.sh"))
        result = self.run_on("work/t5/card.md", "## Step 1\n")
        self.assertEqual(result.get("decision"), "block")
        self.assertIn("could not", result["reason"])

    def test_a_relative_path_is_read_from_the_project(self):
        path = os.path.join(self.project, "work", "t5", "handoff.md")
        with open(path, "w") as f:
            f.write("## Step 1 FAIL\n")
        data = {"tool_name": "Write", "tool_input": {"file_path": "work/t5/handoff.md"}}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env, cwd=tempfile.mkdtemp())
        self.assertEqual(json.loads(out.stdout or "{}").get("decision"), "block")

    def test_files_outside_work_are_left_alone(self):
        self.assertEqual(self.run_on("src/x.luau", "-- FAIL\n"), {})
        self.assertEqual(self.run_on("work/t5/notes.md", "FAIL\n"), {})


if __name__ == "__main__":
    unittest.main()
