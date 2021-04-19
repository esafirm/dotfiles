# Incldue stdlib
source ~/dotfiles/stdlib.sh

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="bullet-train"

source ~/dotfiles/plugins

# User configuration
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# export MANPATH="/usr/local/man:$MANPATH"

## ZSH Syntax Highlighting
isMac && source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

## Init Oh My ZSH
source $ZSH/oh-my-zsh.sh

## Bullet-train
BULLETTRAIN_DIR_BG="blue"
BULLETTRAIN_DIR_FG="white"
BULLETTRAIN_CONTEXT_DEFAULT_USER=$(whoami)
BULLETTRAIN_PROMPT_ORDER=(${BULLETTRAIN_PROMPT_ORDER:#(nvm)})
BULLETTRAIN_PROMPT_ORDER=(
    time
    status
    custom
    context
    dir
    #perl
    ruby
    virtualenv
    #nvm
    #aws
    #go
    #elixir
    git
    #hg
    cmd_exec_time
)

# Dotfiles
export DOT="$HOME/dotfiles"

# Linux specific
if isLinux; then
    source ./linux/path.sh
fi

## Node
source ~/dotfiles/node/nodepath

## Ruby
source ~/dotfiles/ruby/ruby.path

## Android
source ~/dotfiles/android/android.path
source ~/dotfiles/android/func

## Aliases
source ~/dotfiles/aliases

## Secrets
source ~/dotfiles/secrets

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

## Kscript (Kotlin Script)
source ~/dotfiles/kscripts/aliases

# Fastlane
export PATH="$HOME/.fastlane/bin:$PATH"

# Flutter
export PATH="/usr/local/Manual/flutter/bin:$PATH"
export PATH="$HOME/Applications/flutter/bin:$PATH"
export PATH="$HOME/Applications/flutter/bin/cache/dart-sdk/bin:$PATH"

# Local bin
export PATH="$HOME/Applications/local/bin:$PATH"

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.zsh ]] && . /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.zsh ]] && . /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.zsh

# Go Path
export GOPATH="$HOME/Documents/Go"
export PATH="$GOPATH/bin:$PATH"

# OpenVPN
export PATH="/usr/local/opt/openvpn/sbin:$PATH"

# added by travis gem
[ -f /Users/esafirm/.travis/travis.sh ] && source /Users/esafirm/.travis/travis.sh

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/esafirm/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/esafirm/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/esafirm/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/esafirm/google-cloud-sdk/completion.zsh.inc'; fi

export COVERAGE_BLOCKING_LEVEL=35

## Make ^ working
setopt NO_NOMATCH

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/esafirm/.sdkman"
[[ -s "/Users/esafirm/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/esafirm/.sdkman/bin/sdkman-init.sh"
