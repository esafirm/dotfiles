#!/usr/bin/env bash

## Make sure we're on dotfiles
cd ~/dotfiles

## Install required plugins
# ZSH syntax highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

## After this run ~/dotfiles/setup.sh
echo "Done. Now run $DOT/setup.sh"