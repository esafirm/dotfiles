#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../setup-common.sh"
[[ $# -eq 0 ]] || { printf 'Use ./setup.sh --only theme for options such as --dry-run.\n' >&2; exit 2; }

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [[ ! -d "$ZSH" ]]; then
  printf 'Skip theme: Oh My Zsh is missing.\n'
  exit 0
fi

# The managed .zshrc already selects bullet-train. Never edit a user's .zshrc here.
setup_link "$SETUP_ROOT/themes/theme.sh" "${ZSH_CUSTOM:-$ZSH/custom}/themes/bullet-train.zsh-theme"
