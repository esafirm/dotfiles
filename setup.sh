#!/usr/bin/env bash

## Make sure we're on dotfiles
cd ~/dotfiles

## Setup ZSH and Brew
bash ./zshr
bash ./zsh_theme
bash ./brew

## Symlink all
ln -s ~/dotfiles/.vimrc ~/.vimrc
ln -s ~/dotfiles/.zshrc ~/.zshrc
ln -s ~/dotfiles/.warprc ~/.warprc

