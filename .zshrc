# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

source ~/dotfiles/plugins

# User configuration
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# export MANPATH="/usr/local/man:$MANPATH"

## Bullet-train
BULLETTRAIN_CONTEXT_BG="red"
BULLETTRAIN_CONTEXT_FG="red"

## ZSH Syntax Highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
source $ZSH/oh-my-zsh.sh

## Bullet-train
BULLETTRAIN_DIR_BG="blue"
BULLETTRAIN_DIR_FG="white"

## Node
source ~/dotfiles/node/nodepath

## Android
source ~/dotfiles/android/android.path
source ~/dotfiles/android/func

## Aliases
source ~/dotfiles/aliases

## MacOS related
for file in ~/dotfiles/osx/*; do
    source $file
done

## Completion
source ~/dotfiles/completion/pip
source ~/dotfiles/completion/npm

## Scripts
for file in ~/dotfiles/scripts/*; do
    source $file
done

source ~/dotfiles/kscripts/aliases

export PATH="/usr/local/opt/ruby@2.3/bin:$PATH"
export PATH="/usr/local/lib/ruby/gems/2.3.0/bin:$PATH"
export PATH="$HOME/.fastlane/bin:$PATH"
export PATH="/usr/local/Manual/flutter/bin:$PATH"

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.zsh ]] && . /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.zsh ]] && . /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.zsh

# Go Path
export GOPATH="$HOME/Documents/Go"
export PATH="$GOPATH/bin:$PATH"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/esa/.sdkman"
[[ -s "/Users/esa/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/esa/.sdkman/bin/sdkman-init.sh"
