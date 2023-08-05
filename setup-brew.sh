#!/usr/bin/env bash

/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew update && brew upgrade

# Non Cask
NONCASK=(
    mitmproxy
    ssh-copy-id
    tmux
    httpie
    wget
    htop
    gifsicle
    cdiff
    tree
    safe-rm
    tldr
    wd
    git-secret
    go
    tokei
)

for item in ${NONCASK[*]}; do
    brew install $item
done;


## Cask
## This is now more like a GUI app

CASKS=(
    google-chrome
    visual-studio-code
    transmission
    jetbrains-toolbox
    shiftit
)

for item in ${CASKS[*]}; do
    brew install $item
done;

# Cleanup
brew cleanup
