#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)
cd $SCRIPT_DIR

while read -r line; do
    code --install-extension $line;
done < extlist