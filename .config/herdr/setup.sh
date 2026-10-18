#!/usr/bin/env bash
set -euo pipefail

## Install herdr plugins declared in config.toml
## - esafirm/herdr-all-hands provides `esafirm.herdr-all-hands.pluck` (prefix+f)
##   and `esafirm.herdr-all-hands.open-url`
##
## Re-running is safe: `herdr plugin install` reinstalls/refreshes the managed checkout.
## Usage: ./.config/herdr/setup.sh (or via ./setup.sh from dotfiles root)

PLUGINS=(
  "esafirm/herdr-all-hands"
)

## Previously used plugins that are no longer referenced in config.toml.
## Kept here so a re-run cleans up stale installs (e.g. after switching plugins).
STALE_PLUGIN_IDS=(
  "hotchpotch.herdr-tiny-fingers"
  "ramarivera.palette"
  "rmarganti.herdr-pluck"
)
STALE_SOURCES=(
  "hotchpotch/herdr-tiny-fingers"
  "ramarivera/herdr-palette"
  "rmarganti/herdr-pluck"
)

if ! command -v herdr >/dev/null 2>&1; then
  echo "herdr binary not found in PATH, skipping plugin install" >&2
  exit 0
fi

for plugin in "${PLUGINS[@]}"; do
  echo "==> herdr plugin install ${plugin} --yes"
  herdr plugin install "${plugin}" --yes
done

## Remove stale plugins, ignoring errors when they are not installed
for stale in "${STALE_PLUGIN_IDS[@]}" "${STALE_SOURCES[@]}"; do
  if herdr plugin list 2>/dev/null | grep -q "${stale}"; then
    echo "==> herdr plugin uninstall ${stale}"
    herdr plugin uninstall "${stale}" || true
  fi
done

echo "==> herdr plugin list"
herdr plugin list

## Apply keybindings that reference plugin actions (no restart needed)
if herdr server reload-config 2>/dev/null; then
  echo "herdr config reloaded"
fi
