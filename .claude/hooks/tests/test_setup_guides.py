#!/usr/bin/env python3
"""Tests for setup-guides.py. Run: python3 .claude/hooks/tests/test_setup_guides.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "setup-guides.py")


def run(data, project):
    env = dict(os.environ, CLAUDE_PROJECT_DIR=project)
    out = subprocess.run(
        [sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env
    )
    return json.loads(out.stdout) if out.stdout.strip() else {}


def decision(result):
    return result.get("hookSpecificOutput", {}).get("permissionDecision")


def context(result):
    return result.get("hookSpecificOutput", {}).get("additionalContext", "")


class SetupGuides(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, ".claude", "rules"))
        self.rule = os.path.join(self.project, ".claude", "rules", "long.md")
        with open(self.rule, "w") as f:
            f.write("line\n" * 250)

    def edit(self, path, old, new):
        return {
            "hook_event_name": "PreToolUse",
            "tool_name": "Edit",
            "tool_input": {"file_path": path, "old_string": old, "new_string": new},
        }

    def test_user_prompt_gets_the_guide_reminder(self):
        result = run({"hook_event_name": "UserPromptSubmit", "prompt": "add a rule"}, self.project)
        self.assertIn("Anthropic", context(result))

    def test_prompt_without_setup_words_gets_no_reminder(self):
        result = run({"hook_event_name": "UserPromptSubmit", "prompt": "move the ladder 2 studs left"}, self.project)
        self.assertEqual(result, {})

    def test_growing_a_rule_file_over_200_lines_is_blocked(self):
        result = run(self.edit(self.rule, "line\n", "line\nmore\n"), self.project)
        self.assertEqual(decision(result), "deny")
        self.assertIn("code.claude.com/docs/en/memory", result["hookSpecificOutput"]["permissionDecisionReason"])

    def test_shrinking_a_long_rule_file_is_allowed_with_a_reminder(self):
        result = run(
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Write",
                "tool_input": {"file_path": self.rule, "content": "line\n" * 240},
            },
            self.project,
        )
        self.assertIsNone(decision(result))
        self.assertIn("code.claude.com/docs/en/memory", context(result))

    def test_writing_a_new_claude_md_over_200_lines_is_blocked(self):
        path = os.path.join(self.project, "CLAUDE.md")
        result = run(
            {"hook_event_name": "PreToolUse", "tool_name": "Write", "tool_input": {"file_path": path, "content": "x\n" * 201}},
            self.project,
        )
        self.assertEqual(decision(result), "deny")

    def test_skill_file_limit_is_500_lines(self):
        path = os.path.join(self.project, ".claude", "skills", "s", "SKILL.md")
        ok = run(
            {"hook_event_name": "PreToolUse", "tool_name": "Write", "tool_input": {"file_path": path, "content": "x\n" * 400}},
            self.project,
        )
        self.assertIsNone(decision(ok))
        self.assertIn("code.claude.com/docs/en/skills", context(ok))
        too_long = run(
            {"hook_event_name": "PreToolUse", "tool_name": "Write", "tool_input": {"file_path": path, "content": "x\n" * 501}},
            self.project,
        )
        self.assertEqual(decision(too_long), "deny")

    def test_agent_file_edit_gets_the_subagent_guide(self):
        path = os.path.join(self.project, ".claude", "agents", "builder.md")
        result = run(
            {"hook_event_name": "PreToolUse", "tool_name": "Write", "tool_input": {"file_path": path, "content": "x\n"}},
            self.project,
        )
        self.assertIn("code.claude.com/docs/en/sub-agents", context(result))

    def test_game_files_are_left_alone(self):
        path = os.path.join(self.project, "src", "server", "init.server.luau")
        result = run(
            {"hook_event_name": "PreToolUse", "tool_name": "Write", "tool_input": {"file_path": path, "content": "x\n" * 900}},
            self.project,
        )
        self.assertEqual(result, {})

    def write_rule(self, name, text):
        path = os.path.join(self.project, ".claude", "rules", name)
        with open(path, "w") as f:
            f.write(text)
        return path

    def agent_edit(self, added):
        path = os.path.join(self.project, ".claude", "agents", "builder.md")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("# Builder\n")
        return run(self.edit(path, "# Builder\n", "# Builder\n" + added + "\n"), self.project)

    def test_a_line_copied_from_another_setup_file_gets_a_duplicate_warning(self):
        self.write_rule("git.md", "# Git\n\n- No AI mentions, badges or watermarks in code comments, docs, README files or commit messages.\n")
        result = self.agent_edit("- Never add AI mentions, badges or watermarks in code comments, docs, README files or commits.")
        self.assertIsNone(decision(result))
        self.assertIn(".claude/rules/git.md:3", context(result))

    def test_a_one_line_pointer_to_the_home_gets_no_duplicate_warning(self):
        self.write_rule("git.md", "# Git\n\n- No AI mentions, badges or watermarks in code comments, docs, README files or commit messages.\n")
        result = self.agent_edit("- No AI mentions (`git.md`, \"No AI attribution\").")
        self.assertNotIn("repeats", context(result))

    def test_a_new_rule_found_nowhere_else_gets_no_duplicate_warning(self):
        self.write_rule("git.md", "# Git\n\n- No AI mentions, badges or watermarks in code comments, docs, README files or commit messages.\n")
        result = self.agent_edit("- Run the whole test suite after every change to the world before the task closes.")
        self.assertNotIn("repeats", context(result))

    def test_shell_write_to_a_setup_file_is_blocked(self):
        for command in [
            "echo hi >> CLAUDE.md",
            "sed -i '' 's/a/b/' .claude/rules/git.md",
            "cat <<'EOF' > .claude/agents/builder.md",
            "printf x | tee .claude/settings.json",
            "cp work/x.md .claude/agents/x.md",
            "mv .claude/rules/a.md work/a.md",
            "git mv .claude/rules/a.md .claude/rules/b.md",
            "cd work && cp x.md ../.claude/skills/s/SKILL.md",
            "python3 - <<'EOF'\nopen('.claude/rules/git.md','w').write('x')\nEOF",
            "python3 -c \"open('CLAUDE.md','w')\"",
            "python3 - <<'EOF'\nopen('.claude/rules/git.md',\n     'w').write('x')\nEOF",
            "python3 -c \"import pathlib; pathlib.Path('CLAUDE.md').open('a').write('x')\"",
            "python3 -c \"import os; os.open('CLAUDE.md', os.O_WRONLY)\"",
            "python3 -c \"import os; os.unlink('.claude/rules/git.md')\"",
            "cd .claude && tee rules/x.md",
            "cd .claude/rules; echo x > a.md",
            "cp -t .claude/rules work/a.md",
            "rm .claude/hooks/git-guard.py",
            "git rm .claude/settings.json",
        ]:
            result = run({"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": command}}, self.project)
            self.assertEqual(decision(result), "deny", command)

    def test_deleting_a_setup_file_is_allowed_with_the_guide_reminder(self):
        # Deleting can't make a file longer, and moving text out of a rule needs it.
        for command in ["rm .claude/rules/tdd.md", "git rm .claude/rules/sdd.md"]:
            result = run({"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": command}}, self.project)
            self.assertIsNone(decision(result), command)
            self.assertIn("Anthropic", context(result), command)

    def test_shell_reads_of_setup_files_are_allowed(self):
        for command in ["wc -l CLAUDE.md .claude/rules/*.md", "grep -n paths .claude/rules/git.md", "sed -n 1,20p CLAUDE.md", "git add CLAUDE.md", "wc -l CLAUDE.md 2>/dev/null", "cat CLAUDE.md > work/copy.md", "cp .claude/agents/x.md work/", "cat .claude/rules/git.md | tee work/x.md", "rm work/old.md && wc -l CLAUDE.md", "sed -i '' -e 's/CLAUDE.md/x/' work/a.md", "sed -i 's#.claude/rules#x#' work/a.md", "cd .claude && cat rules/git.md"]:
            result = run({"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": command}}, self.project)
            self.assertIsNone(decision(result), command)

    def test_python_that_only_reads_a_setup_file_is_allowed(self):
        # A quoted letter is only a write mode inside open(); a test filter or a count is not.
        for command in ["python3 .claude/hooks/tests/test_setup_guides.py -k \"a\"", "python3 -c \"print(open('CLAUDE.md').read().count('x'))\""]:
            result = run({"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": command}}, self.project)
            self.assertIsNone(decision(result), command)


if __name__ == "__main__":
    unittest.main()
