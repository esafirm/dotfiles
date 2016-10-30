#!/usr/bin/env bash

sh ./zsh.sh
sh ./brew.sh

# Symlink all
ln -s ~/dotfiles/.vimrc ~/.vimrc

echo 'source ~/dotfiles/aliases' >> ~/.zshrc
echo 'source ~/android/android.path' >> ~.zshrc
