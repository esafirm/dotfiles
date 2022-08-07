#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $0)
code --list-extensions > "$SCRIPT_DIR/extlist"
echo "extlist updated!"