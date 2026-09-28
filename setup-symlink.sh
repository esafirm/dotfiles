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
ln -sfn ~/dotfiles/.gemini/policies ~/.gemini/policies
ln -sfn ~/dotfiles/.gemini/settings.json ~/.gemini/settings.json
ln -sfn ~/dotfiles/.gemini/projects.json ~/.gemini/projects.json
ln -sfn ~/dotfiles/.gemini/GEMINI.md ~/.gemini/GEMINI.md
mkdir -p ~/.gemini/antigravity-cli
ln -sfn ~/dotfiles/.gemini/antigravity-cli/settings.json ~/.gemini/antigravity-cli/settings.json
ln -sfn ~/dotfiles/.gemini/extensions/extension-enablement.json ~/.gemini/extensions/extension-enablement.json
ln -sfn ~/dotfiles/.gemini/skills ~/.gemini/skills
ln -sfn ~/dotfiles/.gemini/config/mcp_config.json ~/.gemini/config/mcp_config.json

## Claude Code
mkdir -p ~/.claude
ln -sfn ~/dotfiles/.config/claude/settings.json ~/.claude/settings.json
ln -sfn ~/dotfiles/.config/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sfn ~/dotfiles/.config/claude/skills ~/.claude/skills

## opencode
mkdir -p ~/.config/opencode
ln -sfn ~/dotfiles/opencode.jsonc ~/.config/opencode/opencode.jsonc
ln -sfn ~/dotfiles/.config/claude/CLAUDE.md ~/.config/opencode/AGENTS.md
ln -sfn ~/dotfiles/.config/opencode/cli.json ~/.config/opencode/cli.json
mkdir -p ~/.config/opencode/plugins
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

## Jenkins CLI
mkdir -p ~/scripts
ln -sfn ~/dotfiles/kotlin/kscripts/jenkins-cli.main.kts ~/scripts/jenkins-cli.main.kts
# Expose Jenkins CLI on PATH as `jenkins` (wrapper in kotlin/kscripts,
# since a bare symlink without the .kts extension is not treated as a script)
ln -sfn ~/dotfiles/kotlin/kscripts/jenkins ~/dotfiles/bin/jenkins

## herdr
mkdir -p ~/.config/herdr
ln -sfn ~/dotfiles/.config/herdr/config.toml ~/.config/herdr/config.toml

## Ghostty
mkdir -p ~/.config/ghostty
ln -sfn ~/dotfiles/.config/ghostty/config ~/.config/ghostty/config
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
ln -sfn ~/dotfiles/.config/ghostty/config ~/Library/Application\ Support/com.mitchellh.ghostty/config
