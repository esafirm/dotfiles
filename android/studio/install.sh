#!/usr/bin/env bash

echo "Installing Android Studio dotfiles..."

STUDIO=~/Library/Preferences/AndroidStudio2.2
for file in *; do rm -r $STUDIO/$file; done
for file in *; do ln -sF ~/dotfiles/android/studio/$file $STUDIO; done

echo "Done installing Android Studio dotfiles..."
