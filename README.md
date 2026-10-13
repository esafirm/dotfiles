## Esa's Dotfiles

> This is a readme directed mainly for me.

## Setup

The first thing you should remember is:

1. Generate yout SSH key
2. Update that key to remote repo (Github for dotfiles)
3. Clone dotfiles to `~/dotfiles`

You don't need to:

1. Install oh-my-zsh and set the theme manually
2. Set default login shell to zsh 


So what you've got to do is:

1. Run `./setup-zsh.sh` to setup ZSH
2. Run `./setup.sh` to install everything else

Please read the script first when you want to run it. 

## VScode 

> We do have an instruction in the README file in `/vscode` 

## Android 

> We do have an instruction in the README file in `/android` 

## Vim

For plugin we use [vim-plug](https://github.com/junegunn/vim-plug) and the setup is already included in `setup.sh`

## Agent instructions

`.agents/AGENTS.md` is the single shared instruction file. `setup-symlink.sh` links it to `~/.claude/CLAUDE.md`, `~/.gemini/GEMINI.md`, and `~/.config/opencode/AGENTS.md`. Claude Code only reads `AGENTS.md` at project level, so the user-level `~/.claude/CLAUDE.md` link is still required.

## Command Code

User-scope config lives in `.config/commandcode/` and is symlinked into `~/.commandcode/` by `setup-symlink.sh`:

- `AGENTS.md` — user memory, loaded in every project (imports `~/.claude/CLAUDE.md`)
- `mcp.json` — user-scope MCP servers (android-studio, idea, android-studio-debugger, firebase)
- `settings.json` — extra skill paths (`~/.claude/skills`) and the `PreToolUse` secrets guard
- `commands/` — user slash commands (e.g. `/trash`)
- `hooks/` — hook scripts referenced from `settings.json`

Skills under `~/.agents/skills` are auto-discovered by Command Code and need no extra wiring.
Never version `~/.commandcode/auth.json`, `history.jsonl`, `projects/`, or `file-history/`.

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