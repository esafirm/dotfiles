#!/usr/bin/env bash

# Oh My ZSH
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Oh My ZSH Bullet Train theme
URL = 'https://raw.githubusercontent.com/caiogondim/bullet-train-oh-my-zsh-theme/master/bullet-train.zsh-theme'
curl $URL > $ZSH_CUSTOM/themes/bullet-train.zsh-theme
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="bullet-train"/g' ~/.zshrc

# Change Shell Default to ZSH
chsh -s $(which zsh)

