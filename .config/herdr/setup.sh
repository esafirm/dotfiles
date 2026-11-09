#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../../setup-common.sh"
[[ $# -eq 0 ]] || { printf 'Use ./setup.sh --only plugins for options such as --dry-run.\n' >&2; exit 2; }

## Install herdr plugins declared in config.toml
## - esafirm/herdr-all-hands provides `esafirm.herdr-all-hands.pluck` (prefix+f)
##   and `esafirm.herdr-all-hands.open-url`
##
## Existing plugins are left alone. Updating or uninstalling is a separate action.
## Usage: ./.config/herdr/setup.sh (or via ./setup.sh from dotfiles root)

PLUGINS=(
  "esafirm/herdr-all-hands"
)

if ! command -v herdr >/dev/null 2>&1; then
  echo "herdr binary not found in PATH, skipping plugin install" >&2
  exit 0
fi

installed="$(herdr plugin list)"
for plugin in "${PLUGINS[@]}"; do
  if grep -Fq "$plugin" <<< "$installed"; then
    printf '  Already installed: %s\n' "$plugin"
  else
    setup_run herdr plugin install "$plugin" --yes
  fi
done

## Apply keybindings that reference plugin actions (no restart needed)
if [[ "$SETUP_DRY_RUN" == 1 ]]; then
  setup_run herdr server reload-config
elif ! herdr server reload-config; then
  printf 'Could not reload herdr. Restart it to apply keybindings.\n' >&2
fi
