## Esa's Dotfiles

> This is a readme directed mainly for me.

## Setup

The first thing you should remember is:

1. Generate yout SSH key
2. Update that key to remote repo (Github for dotfiles)
3. Clone dotfiles to `~/dotfiles` (the shell config expects this location)

For the managed shell config, install [Oh My Zsh](https://ohmyz.sh/) first and use Zsh
as your login shell. Setup links the theme but does not install Oh My Zsh or change
your login shell.

Run `./setup.sh`. It previews the changes and asks before applying them (default: no).

```sh
./setup.sh --dry-run          # Preview only. No file changes or installs.
./setup.sh --only links       # Config links, Claude MCP, Git hooks, and Ghostex include.
./setup.sh --only t3          # T3 Code provider instances for OpenCode and both Claude profiles.
./setup.sh --only brew        # Just missing Homebrew packages and apps.
./setup.sh --yes              # Apply all steps without the setup prompt.
./setup.sh --help
```

Setup finds the repository from its own location, not `$DOT` or your working directory.
It skips correct links, missing optional sources, installed packages, and installed herdr plugins.
Oh My Zsh and herdr are optional. Missing tools are reported and their steps skipped.
Homebrew is installed only when missing. Formulae and casks use separate install commands.
There is no bulk upgrade, cleanup, plugin uninstall, or recursive skill deletion. Homebrew
can still install or upgrade dependencies required by a new package. Installers may prompt
for sudo, and herdr plugins are third-party code.
Homebrew metadata is not refreshed automatically. If an install fails because metadata
is stale, run `brew update` yourself before retrying. This does not upgrade packages.

When `jq` is available, unchanged Claude MCP entries are skipped. Otherwise entries
are refreshed on each run, with one full Claude config backup before changes. The
config is `~/.claude.json`, or `$CLAUDE_CONFIG_DIR/.claude.json` when overridden.
Backups are retained without automatic pruning.

Conflicting files, directories, and symlinks are moved intact into a private
`~/.dotfiles-backups/<run>/` directory, preserving physical absolute paths beneath it.
Setup refuses symlinked or foreign-owned backup directories and enforces owner-only
directory access. Configs edited in place (Claude's MCP config, this repo's Git config,
and Ghostex's appearance include) are copied there first. The output shows every backup
path. To restore a conflict, move
the new link aside, then move its backup back to the original path. To undo an in-place
edit, copy the backed-up file over the original. Stop the affected app before restoring
its config, and keep any newer edits you want first. Backups may contain credentials.

Setup stops on errors and names the failed step. Completed steps are not automatically
rolled back. Fix the reported issue and rerun, or use `--only` for the affected step.
Piped/non-interactive runs require `--yes` or `--dry-run`. Prefer this entry point over
the lower-level setup scripts, which apply immediately without arguments and reject
options rather than silently ignoring them.

Safety checks (isolated homes and fake installers, no actual installs):
`python3 -B tests/test_setup.py`.

## VScode 

> We do have an instruction in the README file in `/vscode` 

## Android 

> We do have an instruction in the README file in `/android` 

## Vim

For plugin we use [vim-plug](https://github.com/junegunn/vim-plug) and the setup is already included in `setup.sh`

## Agent instructions

`.agents/AGENTS.md` is the single shared instruction file. `setup-symlink.sh` links it to `~/.claude/CLAUDE.md`, `~/.gemini/GEMINI.md`, and `~/.config/opencode/AGENTS.md`. Claude Code only reads `AGENTS.md` at project level, so the user-level `~/.claude/CLAUDE.md` link is still required.

## T3 Code

`setup-t3.sh` writes T3 Code's provider instances into
`$T3CODE_HOME/userdata/settings.json` (default `~/.t3/userdata/settings.json`).
It keeps every other setting and copies the previous file to the backup directory
first. The step needs `jq` and is skipped when the settings file does not exist.

- `opencode` uses `~/.local/bin/opencode-profile`, so servers that T3 spawns
  honor the global Claude profile.
- `claudeAgent` ("Claude Work") uses `~/.claude-work` as its
  `CLAUDE_CONFIG_DIR`, and `claudeAgentPersonal` ("Claude Personal") uses
  `~/.claude`. Both instances are always available, so the profile picker does
  not change which Claude accounts T3 can use.

Restart T3 Code if a provider instance does not show up after setup.

## MCP Sync

`opencode.jsonc` is the source of truth for MCP servers and their permissions. Claude Code servers are registered by the `claude_mcp` block in `setup-symlink.sh`, and MCP permissions live in `.config/claude/settings.json`.

`.githooks/pre-push` runs `.githooks/verify-mcp-sync` to block pushes when the two drift. `setup-symlink.sh` enables it with `git config core.hooksPath .githooks`.

## Secret checks

The pre-push hook scans committed content in every outgoing commit, including values later deleted or replaced. It checks MCP sync at each pushed tip, independently of uncommitted changes. New branches and unknown remote baselines scan their full reachable history, so old leaks can block them too.

- `python3 -I .githooks/verify-content --all` checks tracked working files.
- `python3 -I .githooks/verify-content --history` checks all locally reachable Git history.
- `python3 -m unittest discover -s tests` runs the regression tests.

Checks cover common token formats, credential fields, sensitive filenames (including binary key containers), and absolute home paths. Tracked symlinks are checked as links, not followed into private local files. Reports never print credential values. A deliberate text match can use `content-check: ignore` on that line. The shared Android debug keystore is intentionally public and is the only key-container filename exception.

Keep workspace trust records and credentials local. If a real secret was committed, revoke or rotate it first. Deleting the current value does not remove it from history. These checks are a safety net, not proof that every possible secret format is absent, and local hooks can be bypassed.

## Manual Setup

Currently, we still need to manually setup this because we haven't found a way to automate it.

- Initliazation of [Cleanshot](https://cleanshot.com/)
## Directory Structure

- `scripts/` — zsh function scripts ONLY (sourced at shell startup via `for file in $DOT/scripts/*; do source $file`). All files here must define shell functions or aliases only, and must never execute commands or call `exec` at top-level. Note: this loop runs *before* Homebrew is in `$PATH`.
- `bin/` — standalone executables and CLI wrappers placed on `$PATH`.
- `kotlin/kscripts/` — Kotlin `.kts` scripts (NOT zsh source-able). Invoked via aliases like `jk='kotlin $DOT/kotlin/kscripts/...'`.

> **Critical Rule:** Never put executable CLI scripts, top-level runner scripts, `.kts`, `.py`, or other non-function files in `scripts/`. They will be `source`d on every shell startup, fail if dependencies like `node` are not in the early `$PATH`, and terminate the login shell (e.g. crashing Ghostty on launch). Executable scripts always belong in `bin/`.

## MCP & Secrets Conventions

1. **No Tokens in Tracked Files**: Sensitive API tokens and credentials must always go into `secrets` (which is `.gitignore`d). Never hardcode tokens in git-tracked MCP JSON files (`mcp_config.json`, `settings.json`, `mcp.json`, `opencode.jsonc`).
2. **No Absolute App Paths in Configs**: Avoid machine-specific paths like `/Applications/LLM Wiki.app/...` in tracked MCP configs.
3. **Use `bin/` Executable Wrappers**: Place a launcher script in `bin/` (e.g. `bin/llm-wiki-mcp`) that:
   - Bootstraps `$PATH` (e.g., includes `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`).
   - Reads the required token dynamically from `$LLM_WIKI_API_TOKEN` or `secrets`.
   - Locates and `exec`s the target runtime.
   - MCP configs can then simply declare `"command": "llm-wiki-mcp"`, keeping the repository safe, portable, and clean.


## Author

esafirm
