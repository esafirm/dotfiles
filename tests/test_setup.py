"""Safety regressions. Fixtures are retained in the session temp dir for inspection."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = (
    "setup.sh", "setup-common.sh", "setup-symlink.sh", "setup-t3.sh", "setup-brew.sh",
    "themes/setup.sh", ".config/herdr/setup.sh",
)


class SetupSafetyTest(unittest.TestCase):
    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="dotfiles-setup-", dir=os.environ.get("TMPDIR"))).resolve()
        self.repo = self.work / "repo with spaces"
        self.home = self.work / "home with spaces"
        self.bin = self.work / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        for script in SCRIPTS:
            dest = self.repo / script
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / script, dest)
        for name in (".vimrc", ".zshrc", "themes/theme.sh", ".config/claude/skills/example/SKILL.md"):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("managed\n")
        self.env = {
            **{key: os.environ[key] for key in ("LANG", "LC_ALL", "TMPDIR") if key in os.environ},
            "HOME": str(self.home), "DOT": "/wrong/repo",
            "CLAUDE_CONFIG_DIR": "",
            "ZSH": str(self.home / ".oh-my-zsh"), "ZSH_CUSTOM": "",
            "SETUP_DRY_RUN": "0", "SETUP_BACKUP_DIR": "",
            "PATH": f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
            "CALL_LOG": str(self.work / "calls"),
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
            "FAKE_BREW_FORMULAE": "", "FAKE_BREW_CASKS": "",
            "FAKE_PLUGINS": "", "FAKE_BREW_FAIL": "0",
            "FAKE_BREW_LIST_FAIL": "0", "FAKE_HERDR_LIST_FAIL": "0",
        }
        subprocess.run(["git", "init", "-q", str(self.repo)], env=self.env, check=True)
        self.stub("uname", "printf 'Darwin\\n'\n")
        self.stub("curl", 'echo unexpected-curl >> "$CALL_LOG"; exit 99\n')
        self.stub("brew", '''
printf 'brew %s\n' "$*" >> "$CALL_LOG"
[[ "$HOMEBREW_NO_AUTO_UPDATE" == 1 && "$HOMEBREW_NO_INSTALL_CLEANUP" == 1 ]] || exit 99
if [[ "$1" == list && "$FAKE_BREW_LIST_FAIL" == 1 ]]; then exit 1; fi
case "$1 $2" in
  'list --formula') printf '%s\n' "$FAKE_BREW_FORMULAE" ;;
  'list --cask') printf '%s\n' "$FAKE_BREW_CASKS" ;;
  'install --formula'|'install --cask') [[ "$FAKE_BREW_FAIL" != 1 ]] ;;
  *) exit 99 ;;
esac
''')
        self.stub("herdr", '''
printf 'herdr %s\n' "$*" >> "$CALL_LOG"
if [[ "$1 $2" == 'plugin list' && "$FAKE_HERDR_LIST_FAIL" == 1 ]]; then exit 1; fi
case "$1 $2" in
  'plugin list') printf '%s\n' "$FAKE_PLUGINS" ;;
  'plugin install'|'server reload-config') ;;
  *) exit 99 ;;
esac
''')
        self.stub("claude", f"exec {shlex.quote(sys.executable)} - \"$@\" <<'PY'\n" + '''
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write("claude " + " ".join(args) + "\\n")
path = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home()) / ".claude.json"
config = json.loads(path.read_text()) if path.exists() else {}
servers = config.setdefault("mcpServers", {})
name = args[4]
if args[1] == "remove":
    if name not in servers:
        print(f'No MCP server named "{name}" in user scope', file=sys.stderr)
        sys.exit(1)
    del servers[name]
elif args[1] == "add-json":
    servers[name] = json.loads(args[5])
else:
    sys.exit(99)
path.write_text(json.dumps(config))
PY
''')
        jq = shutil.which("jq")
        if jq:
            (self.bin / "jq").symlink_to(jq)

    def stub(self, name, body):
        path = self.bin / name
        self.assertFalse(path.is_symlink(), f"Refusing to overwrite a linked executable: {path}")
        path.write_text("#!/bin/bash\nset -eu\n" + body)
        path.chmod(0o755)

    def run_setup(self, *args, expected=0):
        result = subprocess.run(
            ["/bin/bash", str(self.repo / "setup.sh"), *args],
            cwd=self.work, env=self.env, stdin=subprocess.DEVNULL,
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def calls(self):
        path = self.work / "calls"
        return path.read_text() if path.exists() else ""

    def backup_for(self, path):
        matches = list((self.home / ".dotfiles-backups").glob("*/" + str(path).lstrip("/")))
        self.assertEqual(len(matches), 1, matches)
        return matches[0]

    def test_dry_run_and_noninteractive_refusal_do_not_write(self):
        config = self.home / ".zshrc"
        config.write_text("my shell config\n")
        git_config = (self.repo / ".git/config").read_bytes()
        self.run_setup("--dry-run")
        self.run_setup(expected=1)
        self.assertEqual(config.read_text(), "my shell config\n")
        self.assertEqual(list(self.home.iterdir()), [config])
        self.assertEqual((self.repo / ".git/config").read_bytes(), git_config)
        self.assertNotIn("install", self.calls())
        self.assertNotIn("claude ", self.calls())
        self.assertNotIn("reload-config", self.calls())

    def test_links_preserve_files_directories_and_dangling_links(self):
        zshrc = self.home / ".zshrc"
        zshrc.write_text("my shell config\n")
        vimrc = self.home / ".vimrc"
        vimrc.symlink_to("missing-target")
        skills = self.home / ".claude/skills"
        skills.mkdir(parents=True)
        (skills / "personal").write_text("keep me\n")
        claude = self.home / ".claude.json"
        claude.write_text('{"keep":"my runtime state"}\n')
        ghostex = self.home / ".config/ghostex/ghostty/config.ghostty"
        ghostex.parent.mkdir(parents=True)
        ghostex.write_text("font-size = 12\n")
        self.run_setup("--only", "links", "--yes")
        self.assertEqual(zshrc.resolve(), self.repo / ".zshrc")
        self.assertEqual(self.backup_for(zshrc).read_text(), "my shell config\n")
        self.assertEqual(os.readlink(self.backup_for(vimrc)), "missing-target")
        self.assertEqual((self.backup_for(skills) / "personal").read_text(), "keep me\n")
        self.assertEqual(self.backup_for(claude).read_text(), '{"keep":"my runtime state"}\n')
        backup_run = next((self.home / ".dotfiles-backups").iterdir())
        self.assertEqual(backup_run.stat().st_mode & 0o077, 0)
        self.assertEqual(self.backup_for(ghostex).read_text(), "font-size = 12\n")
        before = (self.repo / ".zshrc").read_bytes()
        self.run_setup("--only", "links", "--yes")
        self.assertEqual((self.repo / ".zshrc").read_bytes(), before)
        self.assertEqual(ghostex.read_text().count("config-file ="), 1)
        self.assertFalse((self.home / ".warprc").exists())

    def test_linked_parent_does_not_move_repo_files(self):
        (self.home / ".claude").symlink_to(self.repo / ".config/claude", target_is_directory=True)
        self.run_setup("--only", "links", "--yes")
        skills = self.repo / ".config/claude/skills"
        self.assertFalse(skills.is_symlink())
        self.assertEqual((skills / "example/SKILL.md").read_text(), "managed\n")

    def test_symlinked_backup_root_is_rejected_before_moving_conflict(self):
        outside = self.work / "outside"
        outside.mkdir()
        (self.home / ".dotfiles-backups").symlink_to(outside, target_is_directory=True)
        config = self.home / ".zshrc"
        config.write_text("personal\n")
        output = self.run_setup("--only", "links", "--yes", expected=1)
        self.assertIn("Refusing unsafe backup directory", output)
        self.assertEqual(config.read_text(), "personal\n")
        self.assertFalse(config.is_symlink())
        self.assertEqual(list(outside.iterdir()), [])

    def test_symlinked_backup_run_is_rejected_before_moving_conflict(self):
        root = self.home / ".dotfiles-backups"
        root.mkdir()
        outside = self.work / "outside"
        outside.mkdir()
        run = root / "run"
        run.symlink_to(outside, target_is_directory=True)
        self.env["SETUP_BACKUP_DIR"] = str(run)
        config = self.home / ".zshrc"
        config.write_text("personal\n")
        output = self.run_setup("--only", "links", "--yes", expected=1)
        self.assertIn("Refusing unsafe backup directory", output)
        self.assertEqual(config.read_text(), "personal\n")
        self.assertEqual(list(outside.iterdir()), [])

    def test_existing_backup_root_permissions_are_restricted(self):
        root = self.home / ".dotfiles-backups"
        root.mkdir()
        root.chmod(0o777)
        config = self.home / ".zshrc"
        config.write_text("personal\n")
        self.run_setup("--only", "links", "--yes")
        self.assertEqual(root.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.backup_for(config).read_text(), "personal\n")

    def test_claude_config_override_is_backed_up_without_parent_path_traversal(self):
        default = self.home / ".claude.json"
        default.write_text('{"keep":"default config"}')
        (self.work / "custom").mkdir()
        override = self.work / "override"
        override.mkdir()
        config = override / ".claude.json"
        config.write_text('{"keep":"override config"}')
        self.env["CLAUDE_CONFIG_DIR"] = "custom/../override"
        self.run_setup("--only", "links", "--yes")
        self.assertEqual(self.backup_for(config).read_text(), '{"keep":"override config"}')
        self.assertEqual(default.read_text(), '{"keep":"default config"}')
        self.assertEqual(json.loads(config.read_text())["keep"], "override config")
        self.assertEqual(len(json.loads(config.read_text())["mcpServers"]), 5)

    def test_theme_is_optional_and_rerunnable_without_editing_zshrc(self):
        output = self.run_setup("--only", "theme", "--yes")
        self.assertIn("Skip theme", output)
        self.assertNotIn("setup-zsh.sh", output)
        (self.home / ".oh-my-zsh").mkdir()
        zshrc = self.home / ".zshrc"
        zshrc.write_text('ZSH_THEME="personal"\n')
        for _ in range(2):
            self.run_setup("--only", "theme", "--yes")
        self.assertEqual(zshrc.read_text(), 'ZSH_THEME="personal"\n')
        self.assertTrue((self.home / ".oh-my-zsh/custom/themes/bullet-train.zsh-theme").is_symlink())

    def test_brew_only_installs_missing_packages_with_correct_type(self):
        self.env["FAKE_BREW_FORMULAE"] = "ripgrep\nfzf"
        self.env["FAKE_BREW_CASKS"] = "ghostty"
        self.run_setup("--only", "brew", "--yes")
        calls = self.calls()
        self.assertNotIn("brew install --formula ripgrep", calls)
        self.assertNotIn("brew install --formula fzf", calls)
        self.assertNotIn("brew install --cask ghostty", calls)
        self.assertIn("brew install --formula tmux", calls)
        self.assertIn("brew install --cask google-chrome", calls)
        for forbidden in ("upgrade", "update", "cleanup", "curl", "claude", "herdr"):
            self.assertNotIn(forbidden, calls)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_plugins_keep_existing_and_stale_plugins(self):
        self.env["FAKE_PLUGINS"] = "- esafirm.herdr-all-hands [github:esafirm/herdr-all-hands@abc]"
        self.run_setup("--only", "plugins", "--yes")
        self.assertNotIn("plugin install", self.calls())
        self.assertNotIn("uninstall", self.calls())
        self.assertIn("reload-config", self.calls())

    def t3_settings(self, content):
        settings = self.home / ".t3/userdata/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text(content)
        return settings

    def test_t3_configures_opencode_and_both_claude_profiles(self):
        original = json.dumps({
            "providerInstances": {
                "claudeAgent": {
                    "driver": "claudeAgent",
                    "enabled": True,
                    "config": {"homePath": "/old/work", "launchArgs": "--chrome"},
                },
                "codex": {"driver": "codex", "enabled": False},
            }
        }, indent=2) + "\n"
        settings = self.t3_settings(original)
        self.run_setup("--only", "t3", "--yes")
        configured = json.loads(settings.read_text())["providerInstances"]
        self.assertEqual(configured["opencode"]["config"]["binaryPath"],
                         str(self.home / ".local/bin/opencode-profile"))
        self.assertTrue(configured["opencode"]["enabled"])
        work = configured["claudeAgent"]
        self.assertEqual(work["displayName"], "Claude Work")
        self.assertEqual(work["config"], {"homePath": str(self.home / ".claude-work"), "launchArgs": "--chrome"})
        personal = configured["claudeAgentPersonal"]
        self.assertEqual(personal["driver"], "claudeAgent")
        self.assertEqual(personal["displayName"], "Claude Personal")
        self.assertEqual(personal["config"], {"homePath": str(self.home / ".claude")})
        self.assertEqual(configured["codex"], {"driver": "codex", "enabled": False})
        self.assertEqual(self.backup_for(settings).read_text(), original)

        after_first = settings.read_text()
        output = self.run_setup("--only", "t3", "--yes")
        self.assertIn("Already configured", output)
        self.assertEqual(settings.read_text(), after_first)

    def test_t3_dry_run_does_not_write(self):
        original = '{"providerInstances": {"codex": {"driver": "codex", "enabled": false}}}\n'
        settings = self.t3_settings(original)
        output = self.run_setup("--only", "t3", "--dry-run")
        self.assertIn("Configure T3 Code providers", output)
        self.assertEqual(settings.read_text(), original)
        self.assertFalse((self.home / ".dotfiles-backups").exists())

    def test_missing_plugin_is_installed_only_during_apply(self):
        self.run_setup("--only", "plugins", "--yes")
        self.assertEqual(self.calls().count("herdr plugin install esafirm/herdr-all-hands --yes"), 1)

    def test_failure_stops_and_names_the_step(self):
        self.env["FAKE_BREW_FAIL"] = "1"
        output = self.run_setup("--only", "brew", "--yes", expected=1)
        self.assertIn("Setup stopped during brew", output)
        self.assertEqual(self.calls().count("brew install"), 1)

    def test_preview_failures_name_step_without_claiming_partial_changes(self):
        for step, flag in (("brew", "FAKE_BREW_LIST_FAIL"), ("plugins", "FAKE_HERDR_LIST_FAIL")):
            self.env[flag] = "1"
            output = self.run_setup("--only", step, "--dry-run", expected=1)
            self.assertIn(f"Setup stopped during {step} (preview)", output)
            self.assertIn("Nothing changed.", output)
            self.assertNotIn("Earlier steps", output)
            self.env[flag] = "0"
        self.assertEqual(list(self.home.iterdir()), [])

    def test_syntax_failure_names_step_before_any_changes(self):
        with (self.repo / "setup-symlink.sh").open("a") as script:
            script.write("\nif then\n")
        output = self.run_setup("--dry-run", expected=2)
        self.assertIn("Setup stopped during links (syntax check)", output)
        self.assertIn("Nothing changed.", output)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_only_prints_warnings_for_selected_steps(self):
        for step in ("links", "t3", "theme", "brew", "plugins"):
            output = self.run_setup("--only", step, "--dry-run")
            self.assertEqual("Claude MCP entries" in output, step == "links")
            self.assertEqual("T3 Code provider settings" in output, step == "t3")
            self.assertEqual("Plugins may download" in output, step == "plugins")

    def test_absent_mcp_removals_are_quiet(self):
        output = self.run_setup("--only", "links", "--yes")
        self.assertNotIn("No MCP server named", output)
        self.assertEqual(self.calls().count("claude mcp add-json"), 5)

    @unittest.skipUnless(shutil.which("jq"), "jq is optional for MCP comparison")
    def test_unchanged_mcp_entries_do_not_rewrite_or_create_backups(self):
        self.run_setup("--only", "links", "--yes")
        config = self.home / ".claude.json"
        entries = json.loads(config.read_text())
        for server in entries["mcpServers"].values():
            server.setdefault("args", [])
            server.setdefault("env", {})
        config.write_text(json.dumps(entries))
        content = config.read_bytes()
        calls = self.calls()
        backups = list((self.home / ".dotfiles-backups").iterdir())
        self.run_setup("--only", "links", "--yes")
        self.assertEqual(config.read_bytes(), content)
        self.assertEqual(self.calls(), calls)
        self.assertEqual(list((self.home / ".dotfiles-backups").iterdir()), backups)

    @unittest.skipUnless(shutil.which("jq"), "jq is optional for MCP comparison")
    def test_changed_mcp_entry_is_backed_up_and_unrelated_entries_are_kept(self):
        self.run_setup("--only", "links", "--yes")
        path = self.home / ".claude.json"
        config = json.loads(path.read_text())
        config["mcpServers"]["slack"]["url"] = "https://old.example/mcp"
        config["mcpServers"]["personal"] = {"type": "stdio", "command": "personal-mcp"}
        path.write_text(json.dumps(config))
        before = path.read_bytes()
        calls = self.calls()
        self.run_setup("--only", "links", "--yes")
        self.assertEqual(self.backup_for(path).read_bytes(), before)
        self.assertEqual(self.calls()[len(calls):].count("claude mcp add-json"), 1)
        config = json.loads(path.read_text())
        self.assertEqual(config["mcpServers"]["slack"]["url"], "https://mcp.slack.com/mcp")
        self.assertEqual(config["mcpServers"]["personal"]["command"], "personal-mcp")

    def test_without_jq_refreshes_mcp_with_one_backup(self):
        # A non-working jq exercises the same fallback as a missing optional parser.
        jq = self.bin / "jq"
        if jq.is_symlink():
            jq.rename(self.bin / "jq.disabled")
        self.stub("jq", "exit 127\n")
        config = self.home / ".claude.json"
        config.write_text('{"keep":"my runtime state"}\n')
        self.run_setup("--only", "links", "--yes")
        self.assertEqual(self.backup_for(config).read_text(), '{"keep":"my runtime state"}\n')
        self.assertEqual(self.calls().count("claude mcp add-json"), 5)

    def test_invalid_options_and_help_do_not_write(self):
        for args in (("--unknown",), ("--only",), ("--only", "invalid")):
            self.run_setup(*args, expected=2)
        self.run_setup("--help")
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertEqual(self.calls(), "")

    def test_lower_level_scripts_reject_options_instead_of_applying_them(self):
        for script in ("setup-symlink.sh", "setup-brew.sh", "themes/setup.sh", ".config/herdr/setup.sh"):
            result = subprocess.run(
                ["/bin/bash", str(self.repo / script), "--dry-run"],
                cwd=self.work, env=self.env, stdin=subprocess.DEVNULL,
                capture_output=True, text=True, timeout=15,
            )
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("Use ./setup.sh --only", result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertEqual(self.calls(), "")

    def test_confirmation_defaults_to_no(self):
        master, slave = os.openpty()
        try:
            os.write(master, b"\n")
            result = subprocess.run(
                ["/bin/bash", str(self.repo / "setup.sh"), "--only", "links"],
                cwd=self.work, env=self.env, stdin=slave,
                capture_output=True, text=True, timeout=15,
            )
        finally:
            os.close(master)
            os.close(slave)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Cancelled. Nothing changed.", result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertEqual(self.calls(), "")

    def test_bash_syntax(self):
        for script in SCRIPTS:
            subprocess.run(["/bin/bash", "-n", str(self.repo / script)], check=True)


if __name__ == "__main__":
    unittest.main()
