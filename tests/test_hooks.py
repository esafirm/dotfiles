"""Pre-push safety regressions. Temporary repositories are retained for inspection."""

import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ZERO = "0" * 40
TOKEN = "ghp_" + "a" * 36


class ContentPatternsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.check = staticmethod(runpy.run_path(str(ROOT / ".githooks/verify-content"))["check_data"])

    def test_credentials_are_redacted(self):
        for text in (
            TOKEN,
            json.dumps({"password": "aB7!" * 4}),
            json.dumps({"ANTHROPIC_AUTH_TOKEN": "aB7!" * 4}),
            'Authorization: Bearer ' + "aB7" * 10,
            "postgres://user:" + "aB7!" * 4 + "@localhost/db",
            'token = "example' + "aB7" * 12 + '"',
        ):
            with self.subTest(text_type=text.split(":")[0][:20]):
                issues = self.check("config.json", text.encode())
                self.assertTrue(issues)
                self.assertNotIn(text, "\n".join(issues))

    def test_templates_and_code_references_are_allowed(self):
        for text in (
            'token = "${API_TOKEN}"',
            'token = "your-token-goes-here-please-replace"',
            'password = "<PASSWORD>"',
            "result.secret = cred.secret.plainText",
            "result.password = cred.password.plainText",
            TOKEN + " # content-check: ignore",
        ):
            self.assertEqual(self.check("example", text.encode()), [])

    def test_no_config_file_is_exempt_from_secrets(self):
        self.assertTrue(self.check(".gemini/antigravity-cli/settings.json", TOKEN.encode()))

    def test_sensitive_binary_filenames_are_blocked(self):
        for path in (".env", ".env.local", "auth.json", "release.keystore", "keys/id_rsa", "secrets", ".aws/credentials"):
            self.assertTrue(self.check(path, b"\0binary"), path)
        self.assertEqual(self.check("android/debug.keystore", b"\0binary"), [])
        self.assertEqual(self.check(".env.example", b"TOKEN=$API_TOKEN"), [])


class PushHookTest(unittest.TestCase):
    def setUp(self):
        self.repo = Path(tempfile.mkdtemp(prefix="dotfiles-hooks-", dir=os.environ.get("TMPDIR"))).resolve()
        self.env = {
            **os.environ,
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com",
            "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com",
        }
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
            self.env.pop(key, None)
        self.git("init", "-q")
        shutil.copytree(ROOT / ".githooks", self.repo / ".githooks")
        self.write("opencode.jsonc", '{"mcp":{"servers":{}}}')
        self.write(".config/claude/settings.json", "{}")
        self.write("setup-symlink.sh", "# no MCP servers\n")
        self.write("config", "safe\n")
        self.base = self.commit()

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.repo), *args], env=self.env,
            check=True, capture_output=True, text=True,
        ).stdout.strip()

    def write(self, path, text):
        dest = self.repo / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text)

    def commit(self):
        self.git("add", ".")
        self.git("-c", "commit.gpgsign=false", "commit", "-qm", "fixture")
        return self.git("rev-parse", "HEAD")

    def scan(self, tip=None, old=None, *, expected=0, hook="verify-content", refs=None, args=()):
        refs = refs if refs is not None else f"refs/heads/test {tip or self.git('rev-parse', 'HEAD')} refs/heads/test {old or self.base}\n"
        command = ["bash"] if hook == "pre-push" else [sys.executable, "-I"]
        result = subprocess.run(
            [*command, str(self.repo / ".githooks" / hook), *args],
            input=refs, cwd=self.repo, env=self.env, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertNotIn(TOKEN, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_worktree_cannot_hide_committed_secret(self):
        self.write("config", TOKEN)
        tip = self.commit()
        self.write("config", "safe\n")
        output = self.scan(tip, expected=1)
        self.assertIn("config:1", output)
        self.assertIn(tip[:12], output)

    def test_uncommitted_secret_does_not_block_clean_commit(self):
        self.write("config", "new safe\n")
        tip = self.commit()
        self.write("config", TOKEN)
        self.scan(tip)
        self.scan(args=("--all",), expected=1)

    def test_secret_removed_in_later_commit_is_still_blocked(self):
        self.write("config", TOKEN)
        self.commit()
        self.write("config", "safe\n")
        self.commit()
        self.scan(expected=1)

    def test_root_commit_and_new_branch_are_scanned(self):
        self.write("config", TOKEN)
        tip = self.commit()
        self.git("update-ref", "refs/remotes/unrelated/test", tip)
        self.scan(tip, ZERO, expected=1)
        self.scan(self.base, ZERO)

    def test_secret_in_root_commit_is_scanned(self):
        self.git("checkout", "--orphan", "new-root")
        self.write("config", TOKEN)
        tip = self.commit()
        self.scan(tip, ZERO, expected=1)

    def test_annotated_commit_tag_is_scanned(self):
        self.write("config", TOKEN)
        self.commit()
        self.git("-c", "tag.gpgsign=false", "tag", "-am", "fixture", "release")
        self.scan(self.git("rev-parse", "release"), self.base, expected=1)

    def test_non_commit_tag_is_blocked(self):
        blob = self.git("rev-parse", "HEAD:config")
        self.scan(blob, ZERO, expected=1)

    def test_merge_introducing_secret_is_scanned(self):
        self.git("checkout", "-qb", "feature")
        self.write("feature", "safe\n")
        feature = self.commit()
        self.git("checkout", "-qb", "main-side", self.base)
        self.write("main", "safe\n")
        self.commit()
        self.git("merge", "--no-ff", "--no-commit", feature)
        self.write("config", TOKEN)
        tip = self.commit()
        self.scan(tip, expected=1)

    def test_missing_remote_baseline_falls_back_to_full_history(self):
        self.write("config", TOKEN)
        tip = self.commit()
        self.scan(tip, "f" * 40, expected=1)

    def test_force_push_is_scanned(self):
        self.write("config", TOKEN)
        bad = self.commit()
        self.git("checkout", "-qb", "diverged", self.base)
        self.write("other", "safe\n")
        other = self.commit()
        self.scan(bad, other, expected=1)

    def test_delete_and_empty_push_are_noops(self):
        self.scan(ZERO, self.base, hook="pre-push")
        self.scan(refs="", hook="pre-push")

    def test_malformed_input_fails_closed(self):
        self.scan(refs="broken input\n", expected=1)
        self.scan(refs="a invalid b invalid\n", expected=1)

    def test_multiple_refs_are_all_scanned(self):
        self.write("config", TOKEN)
        bad = self.commit()
        refs = f"a {self.base} b {self.base}\nc {bad} d {self.base}\n"
        self.scan(refs=refs, expected=1, hook="pre-push")

    def test_symlinks_do_not_read_external_secrets(self):
        outside = self.repo.parent / (self.repo.name + "-private")
        outside.write_text(TOKEN)
        (self.repo / "external").symlink_to(outside)
        self.commit()
        self.scan()
        self.scan(args=("--all",))

    def test_renamed_secret_blobs_are_scanned(self):
        self.write("secret config", TOKEN)
        self.commit()
        (self.repo / "secret config").rename(self.repo / "renamed config")
        self.commit()
        self.scan(expected=1)

    def test_deleted_file_in_outgoing_history_is_scanned(self):
        self.write("config", TOKEN)
        self.commit()
        (self.repo / "config").rename(self.repo.parent / (self.repo.name + "-removed-config"))
        self.commit()
        self.scan(expected=1)

    def test_history_mode_finds_old_values(self):
        self.write("config", TOKEN)
        self.commit()
        self.write("config", "safe\n")
        self.commit()
        self.scan(args=("--history",), expected=1)

    def test_mcp_uses_pushed_tip_not_worktree(self):
        self.write("config", "new safe\n")
        tip = self.commit()
        self.write("opencode.jsonc", "invalid JSON")
        self.scan(tip, hook="pre-push")

    def test_mcp_drift_in_tip_cannot_be_hidden_by_worktree(self):
        self.write("opencode.jsonc", json.dumps({"mcp": {"servers": {
            "example": {"type": "remote", "url": "https://example.com/mcp"}
        }}}))
        tip = self.commit()
        self.write("opencode.jsonc", '{"mcp":{"servers":{}}}')
        self.assertIn("example", self.scan(tip, hook="pre-push", expected=1))

    def test_all_pushed_tips_get_mcp_checks(self):
        self.write("opencode.jsonc", json.dumps({"mcp": {"servers": {
            "example": {"type": "remote", "url": "https://example.com/mcp"}
        }}}))
        bad = self.commit()
        refs = f"a {self.base} b {self.base}\nc {bad} d {self.base}\n"
        self.scan(refs=refs, hook="pre-push", expected=1)


if __name__ == "__main__":
    unittest.main()
