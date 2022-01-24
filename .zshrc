# Dotfiles
export DOT="$HOME/dotfiles"
export BIN="$DOT/bin"

# Incldue stdlib
source $DOT/stdlib.sh

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="bullet-train"

source $DOT/plugins

# User configuration
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# export MANPATH="/usr/local/man:$MANPATH"

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
    # ruby
    virtualenv
    #nvm
    #aws
    #go
    #elixir
    git
    #hg
    cmd_exec_time
)

mkdir -p $BIN

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
source ~/dotfiles/android/func.sh

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

## Kotlin
source $DOT/kotlin/kotlin.sh
source $DOT/kotlin/kscripts/aliases

## Python
source $DOT/python/aliases
source $DOT/python/python.path

# Fastlane
export PATH="$HOME/.fastlane/bin:$PATH"

# Flutter
export PATH="/usr/local/Manual/flutter/bin:$PATH"
export PATH="$HOME/Applications/flutter/bin:$PATH"
export PATH="$HOME/Applications/flutter/bin/cache/dart-sdk/bin:$PATH"

# Local bin
export PATH="$HOME/Applications/local/bin:$PATH"

# Go Path
export GOPATH="$HOME/Documents/Go"
export PATH="$GOPATH/bin:$PATH"

## Make ^ working
setopt NO_NOMATCH

## Secrets
# This is where you keep the configurations specific to the machine
if [ -d "$DOT/keepsecret" ]; then
    source $DOT/keepsecret/secrets.sh
fi

if [ -f "$DOT/secrets" ]; then
    source $DOT/secrets
fi
