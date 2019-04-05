#!/usr/bin/env bash

function update() {
    code --list-extensions > extlist
    echo "extlist updated!"
}

function install() {
    while read -r line; do
        code --install-extension $line;
    done < extlist
}

# Check if the function exists (bash specific)
if declare -f "$1" > /dev/null
then
  # call arguments verbatim
  "$@"
else
  # Show a helpful error
  echo "'$1' is not a known function name" >&2
  exit 1
fi