#!/usr/bin/env bash

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew update && brew upgrade
brew tap caskroom/cask

# Non Cask

NONCASK=(
	zsh-syntax-highlighting
	python3
	ccat
	mitmproxy 
	ssh-copy-id
	tmux
	httpie
	wget
	htop
	ffmpeg
	gifsicle
	cdiff	
)

for item in ${NONCASK[*]}; do
	brew install $item
done;


# Cask

CASKS=(
	google-chrome
	visual-studio-code
	transmission
)

for item in ${CASKS[*]}; do
	brew cask install $item
done;

# Cleanup
brew cleanup
brew cask cleanup
