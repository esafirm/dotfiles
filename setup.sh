#!/usr/bin/env bash

## Make sure we're on dotfiles
cd ~/dotfiles

## Setup ZSH theme
bash ./themes/setup.sh

## Install softwares
bash ./brew

## Symlink all
./setup-symlink.sh