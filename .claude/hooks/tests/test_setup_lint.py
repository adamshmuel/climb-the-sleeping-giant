#!/usr/bin/env python3
"""Tests for setup-lint.py. Run: python3 .claude/hooks/tests/test_setup_lint.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "setup-lint.py")


class SetupLint(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, ".claude", "hooks"))
        open(os.path.join(self.project, ".claude", "hooks", "guard.py"), "w").close()

    def run_on(self, relative, text):
        path = os.path.join(self.project, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
        data = {"hook_event_name": "PostToolUse", "tool_name": "Write", "tool_input": {"file_path": path}}
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout)["reason"] if out.stdout.strip() else ""

    def settings(self, hook):
        return json.dumps({"permissions": {}, "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [hook]}]}})

    def test_a_good_agent_passes(self):
        text = "---\nname: helper\ndescription: >\n  Helps.\nmodel: sonnet\nmaxTurns: 5\n---\nBody\n"
        self.assertEqual(self.run_on(".claude/agents/helper.md", text), "")

    def test_an_agent_without_description_is_sent_back(self):
        self.assertIn("`description` is missing", self.run_on(".claude/agents/a.md", "---\nname: a\n---\n"))

    def test_an_agent_without_frontmatter_is_sent_back(self):
        self.assertIn("no frontmatter", self.run_on(".claude/agents/a.md", "Just text\n"))

    def test_a_misspelled_agent_field_is_sent_back(self):
        reason = self.run_on(".claude/agents/a.md", "---\nname: a\ndescription: d\nmax_turns: 5\n---\n")
        self.assertIn("`max_turns` is not an agent field", reason)

    def test_a_colon_in_an_agent_name_is_sent_back(self):
        reason = self.run_on(".claude/agents/a.md", "---\nname: 'my:agent'\ndescription: d\n---\n")
        self.assertIn("contains `:`", reason)

    def test_a_rule_with_paths_passes(self):
        self.assertEqual(self.run_on(".claude/rules/luau.md", "---\npaths:\n  - src/**\n---\nRule\n"), "")

    def test_a_rule_with_another_field_is_sent_back(self):
        reason = self.run_on(".claude/rules/luau.md", "---\ndescription: x\n---\n")
        self.assertIn("`description` is ignored", reason)

    def test_a_skill_with_a_camel_case_field_is_sent_back(self):
        reason = self.run_on(".claude/skills/s/SKILL.md", "---\ndescription: d\nallowedTools: Read\n---\n")
        self.assertIn("`allowedTools` is not a skill field", reason)

    def test_a_long_skill_description_is_sent_back(self):
        text = "---\ndescription: " + "a" * 1000 + "\nwhen_to_use: " + "b" * 600 + "\n---\n"
        self.assertIn("1600 characters", self.run_on(".claude/skills/s/SKILL.md", text))

    def test_a_long_agent_memory_is_sent_back(self):
        reason = self.run_on(".claude/agent-memory/builder/MEMORY.md", "- line\n" * 201)
        self.assertIn("201 lines", reason)

    def test_a_short_agent_memory_passes(self):
        self.assertEqual(self.run_on(".claude/agent-memory/builder/MEMORY.md", "- line\n" * 200), "")

    def test_broken_settings_json_is_sent_back(self):
        self.assertIn("not valid JSON", self.run_on(".claude/settings.json", "{ nope"))

    def test_an_unknown_settings_key_is_sent_back(self):
        self.assertIn("`allowList` is not a settings key", self.run_on(".claude/settings.json", '{"allowList": []}'))

    def test_a_hook_whose_script_is_missing_is_sent_back(self):
        hook = {"type": "command", "command": 'python3 "$CLAUDE_PROJECT_DIR"/.claude/hooks/gaurd.py', "onFailure": "block"}
        self.assertIn("doesn't exist", self.run_on(".claude/settings.json", self.settings(hook)))

    def test_a_pre_tool_use_hook_without_on_failure_is_sent_back(self):
        hook = {"type": "command", "command": 'python3 "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard.py'}
        self.assertIn("has no onFailure", self.run_on(".claude/settings.json", self.settings(hook)))

    def test_good_settings_pass(self):
        hook = {"type": "command", "command": 'python3 "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard.py', "onFailure": "block"}
        self.assertEqual(self.run_on(".claude/settings.json", self.settings(hook)), "")

    def test_other_files_are_left_alone(self):
        self.assertEqual(self.run_on("docs/notes.md", "---\nanything: x\n---\n"), "")

    def test_the_whole_project_setup_follows_the_guides(self):
        out = subprocess.run([sys.executable, HOOK, "--all"], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout)


if __name__ == "__main__":
    unittest.main()
