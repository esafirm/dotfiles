# This file contains global variables that should be exists in every other dotfiles

# dotfile directory
export DOT="$HOME/dotfiles"

# dotfiles directory from chromebook
export CDOT="$DOT/chromebook"

# global bin directories
export BIN="$DOT/bin"

# bat theme
export BAT_THEME="Dracula"

# Disable Claude Code non-essential traffic by default.
# Remote Control needs feature-flag evaluation, so use `claude-rc` to skip this.
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
