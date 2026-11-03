#!/usr/bin/env python3
"""Tests for session-start.py. Run: python3 .claude/hooks/tests/test_session_start.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "session-start.py")
HEALTH = 'print("Hours worked: 5")\nprint("ALARMS:")\nprint("- Rojo crashed 2 time(s)")\n'
HANDOFF = "# Handoff\n\n## Now\nTask 5 is on step C.\n\n## Studio and tools\nPort 34873.\n"


class SessionStart(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, "scripts"))
        os.makedirs(os.path.join(self.project, "docs"))
        with open(os.path.join(self.project, "scripts", "health.py"), "w") as f:
            f.write(HEALTH)
        with open(os.path.join(self.project, "docs", "handoff.md"), "w") as f:
            f.write(HANDOFF)

    def run_with(self, source):
        data = {"hook_event_name": "SessionStart", "source": source}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        result = json.loads(out.stdout) if out.stdout.strip() else {}
        return result.get("hookSpecificOutput", {}).get("additionalContext", "")

    def test_a_new_session_gets_the_health_alarms_only(self):
        text = self.run_with("startup")
        self.assertIn("Rojo crashed 2", text)
        self.assertNotIn("Hours worked", text)

    def test_a_compacted_chat_gets_the_now_section_back(self):
        text = self.run_with("compact")
        self.assertIn("Task 5 is on step C", text)
        self.assertNotIn("Port 34873", text)

    def test_a_long_now_section_is_cut_with_a_pointer(self):
        with open(os.path.join(self.project, "docs", "handoff.md"), "w") as f:
            f.write("## Now\n" + "word " * 2000 + "\n")
        text = self.run_with("compact")
        self.assertLess(len(text.split()), 650)
        self.assertIn("read docs/handoff.md", text)

    def test_a_missing_handoff_is_quiet(self):
        os.remove(os.path.join(self.project, "docs", "handoff.md"))
        self.assertEqual(self.run_with("compact"), "")


if __name__ == "__main__":
    unittest.main()
