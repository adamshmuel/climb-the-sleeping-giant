#!/usr/bin/env python3
"""Tests for git-guard.py. Run: python3 .claude/hooks/tests/test_git_guard.py"""

import json
import os
import subprocess
import sys
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "git-guard.py")


def run(command, agent_id=None):
    data = {"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": command}}
    if agent_id:
        data["agent_id"] = agent_id
        data["agent_type"] = "builder"
    out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True)
    return json.loads(out.stdout) if out.stdout.strip() else {}


def denied(result):
    return result.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"


def context(result):
    return result.get("hookSpecificOutput", {}).get("additionalContext", "")


class GitGuard(unittest.TestCase):
    def test_staging_everything_is_blocked(self):
        for command in ("git add -A", "git add .", "git add --all", "git add -u", "cd src && git add ."):
            self.assertTrue(denied(run(command)), command)

    def test_staging_by_name_passes(self):
        self.assertEqual(run("git add CLAUDE.md .claude/rules/git.md"), {})

    def test_commit_all_flag_is_blocked(self):
        self.assertTrue(denied(run('git commit -am "Fix the ladder"')))

    def test_history_changes_are_blocked(self):
        for command in (
            "git push",
            "git push origin main",
            'git commit --amend -m "Fix"',
            "git rebase main",
            "git reset --hard HEAD~1",
            "git clean -fd",
            "git -C /tmp/x push",
        ):
            self.assertTrue(denied(run(command)), command)

    def test_soft_reset_of_the_index_passes(self):
        self.assertEqual(run("git reset CLAUDE.md"), {})

    def test_agents_never_commit_or_merge(self):
        self.assertTrue(denied(run('git commit -m "Add coins"', agent_id="a1")))
        self.assertTrue(denied(run("git merge --no-ff v2/x", agent_id="a1")))

    def test_agents_can_read_git(self):
        self.assertEqual(run("git status && git diff --stat", agent_id="a1"), {})

    def test_main_chat_commit_and_merge_pass(self):
        self.assertEqual(run('git commit -m "Add the coin counter" -m "Players see their coins."'), {})
        self.assertEqual(run("git merge --no-ff v2/x"), {})

    def test_ai_attribution_is_blocked(self):
        for message in (
            "Co-Authored-By: Claude <noreply@anthropic.com>",
            "Generated with Claude Code",
            "Written by AI",
        ):
            self.assertTrue(denied(run(f'git commit -m "Add coins" -m "{message}"')), message)

    def test_attribution_inside_a_heredoc_is_blocked(self):
        command = "git commit -F - <<'EOF'\nAdd coins\n\nCo-Authored-By: Claude Opus <noreply@anthropic.com>\nEOF"
        self.assertTrue(denied(run(command)))

    def test_claude_md_in_a_message_passes(self):
        self.assertEqual(run('git commit -m "Shrink CLAUDE.md" -m "Moves .claude/rules text."'), {})

    def test_long_title_gets_a_warning(self):
        result = run('git commit -m "Add a very long commit title that goes well past fifty characters"')
        self.assertFalse(denied(result))
        self.assertIn("50", context(result))

    def test_other_commands_pass(self):
        self.assertEqual(run("ls -la && echo push"), {})


if __name__ == "__main__":
    unittest.main()
