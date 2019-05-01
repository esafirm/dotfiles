#!/usr/bin/env bash

INTELLJ=$1

echo "Installing Intellij version $INTELLJ dotfiles .."

STUDIO="~/Library/Preferences/IdeaIC$INTELLJ"
for file in *; do rm -r $STUDIO/$file; done
for file in *; do ln -sF ~/dotfiles/android/intellij/$file $STUDIO; done

echo "Done installing IntelliJ dotfiles..."
