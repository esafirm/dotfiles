#!/usr/bin/env bash

## Symlink all
ln -sfn ~/dotfiles/.vimrc ~/.vimrc
ln -sfn ~/dotfiles/.zshrc ~/.zshrc
ln -sfn ~/dotfiles/.warprc ~/.warprc
ln -sfn ~/dotfiles/.gitconfig ~/.gitconfig

## Neovim
mkdir -p ~/.config
ln -sfn ~/dotfiles/.config/nvim ~/.config/nvim

## Gemini
mkdir -p ~/.gemini/extensions
mkdir -p ~/.gemini/config
ln -sfn ~/dotfiles/.gemini/settings.json ~/.gemini/settings.json
ln -sfn ~/dotfiles/.gemini/projects.json ~/.gemini/projects.json
ln -sfn ~/dotfiles/.agents/AGENTS.md ~/.gemini/GEMINI.md
mkdir -p ~/.gemini/antigravity-cli
ln -sfn ~/dotfiles/.gemini/antigravity-cli/settings.json ~/.gemini/antigravity-cli/settings.json
ln -sfn ~/dotfiles/.gemini/extensions/extension-enablement.json ~/.gemini/extensions/extension-enablement.json
# ~/.gemini/skills was the Gemini CLI location; skills now come from
# ~/.agents/skills and ~/.claude/skills. Drop a stale link if present.
if [[ -L ~/.gemini/skills ]]; then rm -f ~/.gemini/skills; fi
ln -sfn ~/dotfiles/.gemini/config/mcp_config.json ~/.gemini/config/mcp_config.json

## Claude Code
mkdir -p ~/.claude
ln -sfn ~/dotfiles/.config/claude/settings.json ~/.claude/settings.json
ln -sfn ~/dotfiles/.agents/AGENTS.md ~/.claude/CLAUDE.md
ln -sfn ~/dotfiles/.config/claude/skills ~/.claude/skills
mkdir -p ~/.claude/hooks
ln -sfn ~/dotfiles/.config/claude/hooks/herdr-agent-state.sh ~/.claude/hooks/herdr-agent-state.sh
# MCP servers live in ~/.claude.json (mixed with runtime state), so register them via CLI.
# Keep in sync with opencode.jsonc.
if command -v claude >/dev/null 2>&1; then
  claude_mcp() {
    claude mcp remove -s user "$1" >/dev/null 2>&1
    claude mcp add-json -s user "$1" "$2"
  }
  claude_mcp android-studio '{"type":"http","url":"http://127.0.0.1:64342/stream"}'
  claude_mcp firebase '{"type":"stdio","command":"firebase","args":["mcp","--only","crashlytics","--dir","/tmp"]}'
  claude_mcp llm-wiki '{"type":"stdio","command":"llm-wiki-mcp"}'
  claude_mcp play-store '{"type":"stdio","command":"play-store-mcp"}'
  claude_mcp slack '{"type":"http","url":"https://mcp.slack.com/mcp"}'
fi

## Dotfiles git hooks (pre-push verifies MCP sync between opencode and Claude)
git -C ~/dotfiles config core.hooksPath .githooks

## opencode
mkdir -p ~/.config/opencode
ln -sfn ~/dotfiles/opencode.jsonc ~/.config/opencode/opencode.jsonc
ln -sfn ~/dotfiles/.agents/AGENTS.md ~/.config/opencode/AGENTS.md
ln -sfn ~/dotfiles/.config/opencode/cli.json ~/.config/opencode/cli.json
mkdir -p ~/.config/opencode/plugins
ln -sfn ~/dotfiles/.config/opencode/plugins/auto-mode ~/.config/opencode/plugins/auto-mode
ln -sfn ~/dotfiles/.config/opencode/package.json ~/.config/opencode/package.json
ln -sfn ~/dotfiles/.config/opencode/package-lock.json ~/.config/opencode/package-lock.json
ln -sfn ~/dotfiles/.config/opencode/.gitignore ~/.config/opencode/.gitignore
mkdir -p ~/.config/opencode/agents
ln -sfn ~/dotfiles/.config/opencode/agents/advice.md ~/.config/opencode/agents/advice.md
ln -sfn ~/dotfiles/.config/opencode/agents/pr-reviewer.md ~/.config/opencode/agents/pr-reviewer.md
ln -sfn ~/dotfiles/.config/opencode/agents/verify-finding.md ~/.config/opencode/agents/verify-finding.md
mkdir -p ~/.config/opencode/commands
ln -sfn ~/dotfiles/.config/opencode/commands/workflow-audit.md ~/.config/opencode/commands/workflow-audit.md
ln -sfn ~/dotfiles/.config/opencode/commands/advice.md ~/.config/opencode/commands/advice.md
ln -sfn ~/dotfiles/.config/opencode/commands/review-pr.md ~/.config/opencode/commands/review-pr.md
ln -sfn ~/dotfiles/.config/opencode/commands/verify.md ~/.config/opencode/commands/verify.md
ln -sfn ~/dotfiles/.config/opencode/commands/trash.md ~/.config/opencode/commands/trash.md
mkdir -p ~/.config/opencode/scripts
ln -sfn ~/dotfiles/.config/opencode/scripts/workflow-audit.sh ~/.config/opencode/scripts/workflow-audit.sh
ln -sfn ~/dotfiles/.config/opencode/scripts/review-pr.sh ~/.config/opencode/scripts/review-pr.sh
ln -sfn ~/dotfiles/.config/opencode/scripts/ai-trash.sh ~/.config/opencode/scripts/ai-trash.sh

## Consolidate opencode skill dir to dotfiles-managed .config/claude/skills
rm -rf ~/.config/opencode/skill ~/.config/opencode/skills
ln -sfn ~/.claude/skills ~/.config/opencode/skills

## Command Code
mkdir -p ~/.commandcode
ln -sfn ~/dotfiles/.config/commandcode/AGENTS.md ~/.commandcode/AGENTS.md
ln -sfn ~/dotfiles/.config/commandcode/settings.json ~/.commandcode/settings.json
ln -sfn ~/dotfiles/.config/commandcode/mcp.json ~/.commandcode/mcp.json
ln -sfn ~/dotfiles/.config/commandcode/commands ~/.commandcode/commands
ln -sfn ~/dotfiles/.config/commandcode/hooks ~/.commandcode/hooks

## Agent skills (~/.agents)
ln -sfn ~/dotfiles/.agents/skills ~/.agents/skills
ln -sfn ~/dotfiles/.agents/.skill-lock.json ~/.agents/.skill-lock.json

## Drop dangling skill links in agent fan-out dirs (uninstalled or relocated skills)
for _skilldir in ~/.gemini/antigravity-cli/skills ~/.commandcode/skills ~/.copilot/skills; do
  [ -d "$_skilldir" ] || continue
  find "$_skilldir" -maxdepth 1 -type l ! -exec test -e {} \; -delete 2>/dev/null
done

## Jenkins CLI
mkdir -p ~/scripts
ln -sfn ~/dotfiles/kotlin/kscripts/jenkins-cli.main.kts ~/scripts/jenkins-cli.main.kts
# Expose Jenkins CLI on PATH as `jenkins` (wrapper in kotlin/kscripts,
# since a bare symlink without the .kts extension is not treated as a script)
ln -sfn ~/dotfiles/kotlin/kscripts/jenkins ~/dotfiles/bin/jenkins

## LLM Wiki MCP
mkdir -p ~/.local/bin
ln -sfn ~/dotfiles/bin/llm-wiki-mcp ~/.local/bin/llm-wiki-mcp

## Play Store MCP
ln -sfn ~/dotfiles/bin/play-store-mcp ~/.local/bin/play-store-mcp

## herdr
mkdir -p ~/.config/herdr
ln -sfn ~/dotfiles/.config/herdr/config.toml ~/.config/herdr/config.toml
ln -sfn ~/dotfiles/.config/herdr/presentation.toml ~/.config/herdr/presentation.toml
ln -sfn ~/dotfiles/bin/herdr-presentation ~/.local/bin/herdr-presentation
ln -sfn ~/dotfiles/bin/herdr-presentation-status ~/.local/bin/herdr-presentation-status

## Ghostty
mkdir -p ~/.config/ghostty
ln -sfn ~/dotfiles/.config/ghostty/config ~/.config/ghostty/config
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
ln -sfn ~/dotfiles/.config/ghostty/config ~/Library/Application\ Support/com.mitchellh.ghostty/config
