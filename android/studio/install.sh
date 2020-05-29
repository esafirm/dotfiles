#!/usr/bin/env bash

if [ -z $1 ]; then
	echo "You must specify Android Studio Version: install.sh 3.6"
	exit 1
fi

echo "Installing Android Studio version $1 dotfiles .."

STUDIO=~/Library/Preferences/AndroidStudio$1
for file in *; do rm -r $STUDIO/$file; done
for file in *; do ln -sF ~/dotfiles/android/studio/$file $STUDIO; done

echo "Done installing Android Studio dotfiles..."
