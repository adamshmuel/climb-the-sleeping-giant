#!/usr/bin/env python3
"""Tests for no-idle-stop.py. Run: python3 .claude/hooks/tests/test_no_idle_stop.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "no-idle-stop.py")


def run(opener, tools=(), last_message="", active=False, transcript=True):
    entries = [{"type": "user", "message": {"content": opener}}]
    entries += [{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": t}]}} for t in tools]
    path = os.path.join(tempfile.mkdtemp(), "t.jsonl")
    if transcript:
        with open(path, "w") as f:
            f.write("\n".join(json.dumps(e) for e in entries))
    data = {"hook_event_name": "Stop", "transcript_path": path, "stop_hook_active": active, "last_assistant_message": last_message}
    out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True)
    return json.loads(out.stdout) if out.stdout.strip() else {}


def blocked(result):
    return result.get("decision") == "block"


class NoIdleStop(unittest.TestCase):
    def test_a_promise_with_nothing_started_is_blocked(self):
        self.assertTrue(blocked(run("go on", last_message="Done. I'll start the builder next.")))

    def test_a_promise_with_an_agent_started_passes(self):
        self.assertEqual(run("go on", tools=["Agent"], last_message="I'll start the builder."), {})

    def test_a_hand_back_with_nothing_started_is_blocked(self):
        self.assertTrue(blocked(run("Subagent hand-back: builder finished", last_message="Noted.")))

    def test_the_second_stop_passes(self):
        self.assertEqual(run("go on", last_message="I'll start the builder.", active=True), {})

    def test_a_missing_transcript_still_checks_the_promise(self):
        self.assertTrue(blocked(run("go on", last_message="I will run the tests now.", transcript=False)))

    def test_a_plain_reply_passes(self):
        self.assertEqual(run("go on", last_message="All 13 tests pass."), {})


if __name__ == "__main__":
    unittest.main()
