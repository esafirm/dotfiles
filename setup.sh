#!/usr/bin/env bash

## Make sure we're on dotfiles
cd $DOT

## Setup ZSH theme
./themes/setup.sh

## Install softwares
./setup-brew.sh

## Symlink all
./setup-symlink.sh