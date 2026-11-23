# Every zsh reads this, including the non-interactive shells that agents run.
# Keep it fast and quiet, and never let it fail the shell.

# Local-only variables (git-ignored). Keep that file to plain `export KEY=VALUE` lines.
# The marker stops nested shells from reloading it over per-command overrides.
if [[ -z "${__DOTFILES_LOCAL_VARS_LOADED:-}" && -r "$HOME/dotfiles/secrets" ]]; then
  source "$HOME/dotfiles/secrets" || true
  export __DOTFILES_LOCAL_VARS_LOADED=1
fi
