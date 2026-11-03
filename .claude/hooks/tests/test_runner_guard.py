#!/usr/bin/env python3
"""Tests for runner-guard.py. Run: python3 .claude/hooks/tests/test_runner_guard.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "runner-guard.py")


class RunnerGuard(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, "work"))

    def decision(self, tool, tool_input):
        data = {"hook_event_name": "PreToolUse", "tool_name": tool, "tool_input": tool_input}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        result = json.loads(out.stdout) if out.stdout.strip() else {}
        return result.get("hookSpecificOutput", {}).get("permissionDecision", "allow")

    def bash(self, command):
        return self.decision("Bash", {"command": command})

    def test_reading_commands_pass(self):
        for command in ("cat work/t5/note.md", "ls work | grep t5", "git status --short", "git log --oneline -n5"):
            self.assertEqual(self.bash(command), "allow", command)

    def test_the_job_check_and_the_full_run_wait_pass(self):
        self.assertEqual(self.bash("scripts/job-check.sh --handoff work/t5/card.md"), "allow")
        self.assertEqual(self.bash('python3 -c "import time; time.sleep(62)"'), "allow")

    def test_a_long_wait_is_blocked(self):
        self.assertEqual(self.bash('python3 -c "import time; time.sleep(600)"'), "deny")

    def test_changing_commands_are_blocked(self):
        for command in ("rm work/t5/note.md", "git commit -m x", "git diff --output=x", "python3 tools/x.py"):
            self.assertEqual(self.bash(command), "deny", command)

    def test_redirects_and_hidden_commands_are_blocked(self):
        for command in ("echo x > src/a.luau", "cat a $(rm b)", "ls\nrm x", "cat `rm x`"):
            self.assertEqual(self.bash(command), "deny", command)

    def test_a_note_in_work_can_be_written(self):
        self.assertEqual(self.decision("Write", {"file_path": os.path.join(self.project, "work", "n.md")}), "allow")

    def test_a_write_outside_work_is_blocked(self):
        for path in ("src/server/a.luau", ".claude/agents/runner.md", "work/../src/a.luau"):
            self.assertEqual(self.decision("Edit", {"file_path": path}), "deny", path)

    def test_studio_calls_pass(self):
        self.assertEqual(self.decision("mcp__Roblox_Studio__execute_luau", {"code": "print(1)"}), "allow")


if __name__ == "__main__":
    unittest.main()
