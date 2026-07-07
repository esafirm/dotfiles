#!/usr/bin/env bash

## Symlink all
ln -sf ~/dotfiles/.vimrc ~/.vimrc
ln -sf ~/dotfiles/.zshrc ~/.zshrc
ln -sf ~/dotfiles/.warprc ~/.warprc
ln -sf ~/dotfiles/.gitconfig ~/.gitconfig

## Gemini
mkdir -p ~/.gemini/extensions
ln -sf ~/dotfiles/.gemini/policies ~/.gemini/policies
ln -sf ~/dotfiles/.gemini/settings.json ~/.gemini/settings.json
ln -sf ~/dotfiles/.gemini/projects.json ~/.gemini/projects.json
ln -sf ~/dotfiles/.gemini/GEMINI.md ~/.gemini/GEMINI.md
ln -sf ~/dotfiles/.gemini/extensions/extension-enablement.json ~/.gemini/extensions/extension-enablement.json
ln -sf ~/dotfiles/.gemini/skills ~/.gemini/skills

## Claude Code
mkdir -p ~/.claude
ln -sf ~/dotfiles/.claude/settings.json ~/.claude/settings.json
ln -sf ~/dotfiles/.claude/projects.json ~/.claude/projects.json
ln -sf ~/dotfiles/.claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/dotfiles/.claude/skills ~/.claude/skills

## opencode
mkdir -p ~/.config/opencode
ln -sf ~/dotfiles/opencode.jsonc ~/.config/opencode/opencode.jsonc
mkdir -p ~/.config/opencode/plugins
ln -sf ~/dotfiles/.config/opencode/plugins/rtk.ts ~/.config/opencode/plugins/rtk.ts
ln -sf ~/dotfiles/.config/opencode/plugins/audit-prompts.ts.disabled ~/.config/opencode/plugins/audit-prompts.ts.disabled
ln -sf ~/dotfiles/.config/opencode/package.json ~/.config/opencode/package.json
ln -sf ~/dotfiles/.config/opencode/package-lock.json ~/.config/opencode/package-lock.json
ln -sf ~/dotfiles/.config/opencode/.gitignore ~/.config/opencode/.gitignore
mkdir -p ~/.config/opencode/commands
ln -sf ~/dotfiles/.config/opencode/commands/workflow-audit.md ~/.config/opencode/commands/workflow-audit.md
mkdir -p ~/.config/opencode/scripts
ln -sf ~/dotfiles/.config/opencode/scripts/workflow-audit.sh ~/.config/opencode/scripts/workflow-audit.sh

## Consolidate opencode skill dir to dotfiles-managed .claude/skills
rm -rf ~/.config/opencode/skill ~/.config/opencode/skills
ln -sf ~/.claude/skills ~/.config/opencode/skills

## herdr
mkdir -p ~/.config/herdr
ln -sf ~/dotfiles/.config/herdr/config.toml ~/.config/herdr/config.toml
