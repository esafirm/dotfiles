#!/usr/bin/env bash

## Make sure we're on dotfiles
cd ~/dotfiles

## Setup ZSH and Brew
bash ./zsh
bash ./themes/setup.sh
bash ./brew

## Symlink all
./setup-symlink.sh