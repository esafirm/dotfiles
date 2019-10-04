#!/usr/bin/env bash

INTELLJ=$1

if [ -z "$INTELLJ" ]; then
    echo "No version specified"
    echo "Usage: ./install.sh [version]"
    echo "Example: ./install.sh 2019.2"
    exit 1    
fi

echo "Installing Intellij version $INTELLJ dotfiles .."

INTELLIJ_PATH=~/Library/Preferences/IdeaIC$INTELLJ

echo "=> copying to $INTELLIJ_PATH"

for file in *; do rm -r $INTELLIJ_PATH/$file; done
for file in *; do ln -sF ~/dotfiles/android/intellij/$file $INTELLIJ_PATH; done

echo "Done installing IntelliJ dotfiles..."