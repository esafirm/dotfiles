#!/usr/bin/env bash

THEME_FILE=~/dotfiles/theme/theme.sh

# Sometimes the custom path is empty. Use default one
ZSH_CUSTOM="$ZSH/custom"

# Oh My ZSH Bullet Train theme
BULLET_DIR=$ZSH_CUSTOM/themes/bullet-train.zsh-theme

ln -s $THEME_FILE $BULLET_DIR
sed -i '' 's/ZSH_THEME="robbyrussell"/ZSH_THEME="bullet-train"/g' ~/.zshrc