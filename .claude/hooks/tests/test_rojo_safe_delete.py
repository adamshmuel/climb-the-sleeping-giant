#!/usr/bin/env python3
"""Tests for rojo-safe-delete.py. Run: python3 .claude/hooks/tests/test_rojo_safe_delete.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "rojo-safe-delete.py")


class RojoSafeDelete(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, "src", "a"))
        open(os.path.join(self.project, "src", "a", "x.luau"), "w").close()

    def blocked(self, command):
        data = {"tool_name": "Bash", "tool_input": {"command": command}, "cwd": self.project}
        env = dict(os.environ, CLAUDE_PROJECT_DIR=self.project)
        out = subprocess.run([sys.executable, HOOK], input=json.dumps(data), capture_output=True, text=True, env=env)
        return out.returncode == 2

    def test_removing_a_synced_folder_is_blocked(self):
        self.assertTrue(self.blocked("rm -r src/a"))
        self.assertTrue(self.blocked("mv src/a work/a"))

    def test_the_safe_script_passes(self):
        self.assertFalse(self.blocked("scripts/rojo-safe-rm.sh src/a"))

    def test_naming_the_safe_script_does_not_unlock_rm(self):
        self.assertTrue(self.blocked("echo rojo-safe-rm.sh && rm -r src/a"))

    def test_deleting_one_file_passes(self):
        self.assertFalse(self.blocked("rm src/a/x.luau"))


if __name__ == "__main__":
    unittest.main()
