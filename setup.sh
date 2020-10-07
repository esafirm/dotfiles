#!/usr/bin/env bash

## Make sure we're on dotfiles
cd ~/dotfiles

## Setup ZSH and Brew
bash ./zsh
bash ./themes/setup.sh
bash ./brew

## Symlink all
ln -s ~/dotfiles/.vimrc ~/.vimrc
ln -s ~/dotfiles/.zshrc ~/.zshrc
ln -s ~/dotfiles/.warprc ~/.warprc
ln -s ~/dotfiles/.gitconfig ~/.gitconfig

## Vim Plug install
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim