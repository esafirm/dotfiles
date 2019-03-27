#!/usr/bin/env bash

echo "Installing VSCode configuration files…"

VSCODEDIR="$HOME/Library/Application Support/Code/User"

for file in *; do rm -r "$VSCODEDIR/$file"; done
for file in *; do ln -sF "$HOME/dotfiles/vscode/$file" "$VSCODEDIR"; done

echo "Done installing VSCode configuration files…"
