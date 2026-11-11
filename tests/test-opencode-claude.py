"""Verify profile switching without touching real accounts or launching Claude."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


WRAPPER = Path(__file__).resolve().parents[1] / "bin/opencode-claude"


class ClaudeProfileTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="claude-profile-test-")
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / "home with spaces"
        (self.home / ".claude").mkdir(parents=True)
        (self.home / ".claude-personal").mkdir()
        (self.home / ".local/bin").mkdir(parents=True)
        claude = self.home / ".local/bin/claude"
        claude.write_text('#!/bin/sh\nprintf "%s\\n" "${CLAUDE_CONFIG_DIR:-default}" "$@"\n')
        claude.chmod(0o755)
        self.env = {**os.environ, "HOME": str(self.home),
                    "XDG_STATE_HOME": str(self.home / "state"),
                    "CLAUDE_CONFIG_DIR": "/ignored/inherited/profile"}

    def run_wrapper(self, *args):
        return subprocess.run(["bash", str(WRAPPER), *args], env=self.env,
                              capture_output=True, text=True)

    def test_default_and_argument_forwarding(self):
        result = self.run_wrapper("--model", "opus", "two words")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(),
                         ["default", "--model", "opus", "two words"])

    def test_switch_is_persistent_and_status_does_not_change_it(self):
        for profile, directory in [("personal", ".claude-personal"), ("work", ".claude")]:
            self.assertEqual(self.run_wrapper("--profile", profile).returncode, 0)
            status = self.run_wrapper("--profile", "status")
            self.assertEqual(status.stdout, f"{profile} ({self.home / directory})\n")
            self.assertEqual(self.run_wrapper("auth", "status").stdout.splitlines()[0],
                             "default" if profile == "work" else str(self.home / directory))

    def test_invalid_arguments_do_not_change_selection(self):
        for args in [("--profile",), ("--profile", "../../bad"),
                     ("--profile", "personal", "extra")]:
            self.assertNotEqual(self.run_wrapper(*args).returncode, 0)
        self.assertTrue(self.run_wrapper("--profile", "status").stdout.startswith("work "))

    def test_corrupt_state_fails_closed_and_can_be_repaired(self):
        state = self.home / "state/opencode/claude-profile"
        state.parent.mkdir(parents=True)
        state.write_text("unexpected\n")
        self.assertNotEqual(self.run_wrapper("auth", "status").returncode, 0)
        self.assertEqual(self.run_wrapper("--profile", "work").returncode, 0)


if __name__ == "__main__":
    unittest.main()
