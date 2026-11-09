#!/usr/bin/env bash
# Shared safety helpers. Source this file, do not execute it.

SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export DOT="$SETUP_ROOT"
export SETUP_DRY_RUN="${SETUP_DRY_RUN:-0}"
export SETUP_BACKUP_DIR="${SETUP_BACKUP_DIR:-$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)-$$}"

setup_run() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
  if [[ "$SETUP_DRY_RUN" != 1 ]]; then
    "$@"
  fi
}

setup_backup() {
  local path parent mode="${2:-move}" backup directory
  # Resolve the parent, not the final link, and keep '..' out of backup paths.
  parent="$(cd -- "$(dirname -- "$1")" && pwd -P)"
  path="$parent/$(basename -- "$1")"
  backup="$SETUP_BACKUP_DIR/${path#/}"
  printf '  Back up %s -> %s\n' "$path" "$backup"
  [[ "$SETUP_DRY_RUN" != 1 ]] || return 0
  if [[ -e "$backup" || -L "$backup" ]]; then
    printf 'Backup already exists, refusing to overwrite: %s\n' "$backup" >&2
    return 1
  fi
  for directory in "$HOME/.dotfiles-backups" "$SETUP_BACKUP_DIR"; do
    if [[ -L "$directory" || ( -e "$directory" && ( ! -d "$directory" || ! -O "$directory" ) ) ]]; then
      printf 'Refusing unsafe backup directory: %s\n' "$directory" >&2
      return 1
    fi
    (umask 077; mkdir -p -- "$directory")
    chmod 700 "$directory"
  done
  (umask 077; mkdir -p -- "$(dirname -- "$backup")")
  if [[ "$mode" == copy ]]; then
    cp -pL -- "$path" "$backup"
  else
    mv -- "$path" "$backup"
  fi
}

setup_link() {
  local source="$1" target="$2"
  if [[ ! -e "$source" ]]; then
    printf '  Skip missing source: %s\n' "$source"
    return 0
  fi
  # Also covers relative links and a parent directory already linked into the repo.
  if [[ "$source" -ef "$target" ]]; then
    printf '  Already in place: %s\n' "$target"
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    setup_backup "$target"
  fi
  printf '  Link %s -> %s\n' "$target" "$source"
  if [[ "$SETUP_DRY_RUN" != 1 ]]; then
    mkdir -p -- "$(dirname -- "$target")"
    ln -s -- "$source" "$target"
  fi
}
