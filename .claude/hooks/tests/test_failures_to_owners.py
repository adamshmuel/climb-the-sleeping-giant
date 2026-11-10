#!/usr/bin/env python3
"""Tests for failures-to-owners.py. Run: python3 .claude/hooks/tests/test_failures_to_owners.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "failures-to-owners.py")
HAND_BACK = "[Subagent hand-back] The report follows:\n"


def agent_call(call_id, kind):
    return {
        "type": "assistant",
        "message": {"content": [{"type": "tool_use", "id": call_id, "name": "Agent", "input": {"subagent_type": kind}}]},
    }


def agent_result(call_id, agent_id):
    return {
        "type": "user",
        "message": {"content": [{"type": "tool_result", "tool_use_id": call_id, "content": f"launched. agentId: {agent_id} (internal)"}]},
    }


def tool(name, tool_input):
    return {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "x", "name": name, "input": tool_input}]}}


def run(opener, before=(), after=(), active=False):
    entries = list(before) + [{"type": "user", "message": {"content": opener}}] + list(after)
    path = os.path.join(tempfile.mkdtemp(), "t.jsonl")
    with open(path, "w") as f:
        f.write("\n".join(json.dumps(e) for e in entries))
    data = {"hook_event_name": "Stop", "transcript_path": path, "stop_hook_active": active}
    out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True)
    return json.loads(out.stdout) if out.stdout.strip() else {}


def blocked(result):
    return result.get("decision") == "block"


SHOT_FAIL = HAND_BACK + "Step 6 stopped at shot 1, which FAILED pass line 1."
RUN_PASS = HAND_BACK + "RESULT: PASS\n- FAILED: egg spots (accepted red)"
ACCEPTED_ONLY = HAND_BACK + "Numbers: 3114 passed\n- FAILED: the stuck scan (accepted red)"


class FailuresToOwners(unittest.TestCase):
    def test_a_failed_shot_with_no_owner_is_blocked(self):
        self.assertTrue(blocked(run(SHOT_FAIL, after=[tool("Edit", {"file_path": "a"})])))

    def test_a_failed_shot_asked_of_the_user_is_blocked(self):
        self.assertTrue(blocked(run(SHOT_FAIL, after=[tool("AskUserQuestion", {})])))

    def test_a_failed_shot_sent_to_product_passes(self):
        self.assertEqual(run(SHOT_FAIL, after=[agent_call("c1", "product")]), {})

    def test_a_failed_shot_sent_to_a_builder_is_blocked(self):
        self.assertTrue(blocked(run(SHOT_FAIL, after=[agent_call("c1", "builder")])))

    def test_a_message_to_a_running_owner_passes(self):
        before = [agent_call("c1", "code_lead"), agent_result("c1", "abc123")]
        self.assertEqual(run(SHOT_FAIL, before=before, after=[tool("SendMessage", {"to": "abc123"})]), {})

    def test_a_message_to_a_runner_is_blocked(self):
        before = [agent_call("c1", "runner"), agent_result("c1", "run999")]
        self.assertTrue(blocked(run(SHOT_FAIL, before=before, after=[tool("SendMessage", {"to": "run999"})])))

    def test_a_passing_run_with_accepted_reds_passes(self):
        self.assertEqual(run(RUN_PASS), {})

    def test_only_accepted_reds_passes(self):
        self.assertEqual(run(ACCEPTED_ONLY), {})

    def test_a_user_message_saying_failed_passes(self):
        self.assertEqual(run("the shot FAILED, why?"), {})

    def test_the_second_stop_passes(self):
        self.assertEqual(run(SHOT_FAIL, active=True), {})


if __name__ == "__main__":
    unittest.main()
