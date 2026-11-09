#!/usr/bin/env python3
"""Tests for card-guard.py. Run: python3 .claude/hooks/tests/test_card_guard.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "card-guard.py")


class CardGuard(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, "work", "t5"))
        for name in ("step2-card.md", "t5-handoff.md"):
            open(os.path.join(self.project, "work", "t5", name), "w").close()

    def decision(self, agent, prompt):
        data = {"hook_event_name": "PreToolUse", "tool_name": "Agent",
                "tool_input": {"subagent_type": agent, "prompt": prompt, "description": "x"}}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        result = json.loads(out.stdout) if out.stdout.strip() else {}
        return result.get("hookSpecificOutput", {}).get("permissionDecision", "allow")

    def test_builder_with_a_card_passes(self):
        self.assertEqual(self.decision("builder", "Do Step 2 of work/t5/step2-card.md."), "allow")
        self.assertEqual(self.decision("builder", f"Card: {self.project}/work/t5/t5-handoff.md"), "allow")

    def test_builder_without_a_card_is_blocked(self):
        self.assertEqual(self.decision("builder", "Do plan 5 Task 15b from the plan block."), "deny")
        self.assertEqual(self.decision("builder", "Write results to work/t5/results.md"), "deny")

    def test_a_card_that_does_not_exist_is_blocked(self):
        self.assertEqual(self.decision("builder", "Do work/t5/missing-card.md"), "deny")

    def test_other_agents_are_not_checked(self):
        for agent in ("code_lead", "runner", "product", None):
            self.assertEqual(self.decision(agent, "anything"), "allow", agent)

    def test_bad_input_does_not_block(self):
        out = subprocess.run([sys.executable, HOOK], input="not json", capture_output=True, text=True)
        self.assertEqual(out.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
