#!/usr/bin/env python3
"""Tests for task-clock.py. Run: python3 .claude/hooks/tests/test_task_clock.py"""

import datetime
import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "task-clock.py")


def ago(minutes):
    return (datetime.datetime.now() - datetime.timedelta(minutes=minutes)).strftime("%Y-%m-%d %H:%M")


class TaskClock(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, "work"))

    def run_with(self, clock, event="UserPromptSubmit"):
        if clock is not None:
            with open(os.path.join(self.project, "work", "task-clock.txt"), "w") as f:
                f.write(clock)
        data = {"hook_event_name": event, "tool_name": "Agent", "prompt": "go"}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        return json.loads(out.stdout) if out.stdout.strip() else {}

    def context(self, result):
        return result.get("hookSpecificOutput", {}).get("additionalContext", "")

    def test_a_small_fix_past_10_minutes_raises_the_red_flag(self):
        result = self.run_with(f"Task 5 | small | {ago(12)}")
        self.assertIn("Task 5", self.context(result))
        self.assertIn("stop-and-step-back", self.context(result))

    def test_a_small_fix_inside_10_minutes_is_quiet(self):
        self.assertEqual(self.run_with(f"Task 5 | small | {ago(5)}"), {})

    def test_a_task_past_1_hour_raises_the_red_flag_before_an_agent_starts(self):
        result = self.run_with(f"Task 6 | task | {ago(61)}", event="PreToolUse")
        self.assertEqual(result["hookSpecificOutput"]["hookEventName"], "PreToolUse")
        self.assertIn("Task 6", self.context(result))

    def test_a_task_inside_1_hour_is_quiet(self):
        self.assertEqual(self.run_with(f"Task 6 | task | {ago(50)}"), {})

    def test_no_clock_or_a_closed_task_is_quiet(self):
        self.assertEqual(self.run_with(None), {})
        self.assertEqual(self.run_with(f"Task 6 | done | {ago(300)}"), {})

    def test_a_broken_clock_line_says_how_to_fix_it(self):
        self.assertIn("task-clock.txt", self.context(self.run_with("oops")))


if __name__ == "__main__":
    unittest.main()
