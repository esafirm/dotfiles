#!/usr/bin/env bash

# Oh My ZSH
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Oh My ZSH Bullet Train theme
source zsh_theme

# Change Shell Default to ZSH
chsh -s $(which zsh)

