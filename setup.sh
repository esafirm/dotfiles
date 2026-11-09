#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/setup-common.sh"

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--yes] [--only links|theme|brew|plugins]

Preview changes, then ask before applying them. Existing configs are backed up.

  --dry-run   Show changes without writing files or installing anything
  --yes       Apply without the setup confirmation (installers may still prompt)
  --only STEP Run just one step
  -h, --help  Show this help

Examples:
  ./setup.sh --dry-run
  ./setup.sh --only links
  ./setup.sh --only brew --yes
EOF
}

yes=0
only=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) SETUP_DRY_RUN=1 ;;
    --yes) yes=1 ;;
    --only)
      [[ $# -gt 1 ]] || { usage >&2; exit 2; }
      only="$2"
      case "$only" in
        links|theme|brew|plugins) ;;
        *) printf 'Unknown step: %s\n' "$only" >&2; exit 2 ;;
      esac
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

steps=(links theme brew plugins)
[[ -z "$only" ]] || steps=("$only")
step_script() {
  case "$1" in
    links) printf '%s/setup-symlink.sh' "$SETUP_ROOT" ;;
    theme) printf '%s/themes/setup.sh' "$SETUP_ROOT" ;;
    brew) printf '%s/setup-brew.sh' "$SETUP_ROOT" ;;
    plugins) printf '%s/.config/herdr/setup.sh' "$SETUP_ROOT" ;;
  esac
}

phase="syntax check"
setup_failed() {
  printf '\nSetup stopped during %s (%s).\n' "$step" "$phase" >&2
  if [[ "$phase" == apply ]]; then
    printf 'Earlier steps may have completed.\nBackups, if any: %s\n' "$SETUP_BACKUP_DIR" >&2
  else
    printf 'Nothing changed.\n' >&2
  fi
  printf 'Fix the error and rerun the same command.\n' >&2
}
trap setup_failed ERR

for step in "${steps[@]}"; do
  bash -n "$(step_script "$step")"
done

printf 'Dotfiles: %s\n' "$SETUP_ROOT"
printf 'Plan: %s\n' "${steps[*]}"
printf 'No bulk package upgrades, cleanup, or recursive deletion. Conflicts are backed up.\n'
for step in "${steps[@]}"; do
  case "$step" in
    links) printf 'Claude MCP entries and this repo\047s hooks path will be configured in the links step.\n' ;;
    plugins) printf 'Plugins may download and execute third-party code. Existing plugins are kept.\n' ;;
  esac
done
printf '\nPreview (no changes):\n'
phase=preview
for step in "${steps[@]}"; do
  printf '\n==> %s\n' "$step"
  SETUP_DRY_RUN=1 bash "$(step_script "$step")"
done

if [[ "$SETUP_DRY_RUN" == 1 ]]; then
  printf '\nPreview complete. Nothing changed.\n'
  exit 0
fi

if [[ "$yes" != 1 ]]; then
  if [[ ! -t 0 ]]; then
    printf '\nNo terminal. Use --dry-run to preview or --yes to apply.\n' >&2
    exit 1
  fi
  printf '\nApply this plan? [y/N] '
  read -r answer || exit 1
  case "$answer" in
    y|Y|yes|YES) ;;
    *) printf 'Cancelled. Nothing changed.\n'; exit 0 ;;
  esac
fi

phase=apply
for step in "${steps[@]}"; do
  printf '\n==> Applying %s\n' "$step"
  bash "$(step_script "$step")"
done
printf '\nSetup complete. Backups, if any: %s\n' "$SETUP_BACKUP_DIR"
