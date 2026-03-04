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
