#!/usr/bin/env bash
# ai-trash.sh — sanctioned deletion path for agents.
# `rm` on repo files is denied by tool permissions, so agents NEVER delete
# in place. This script stages doomed files in a per-repo trash dir under
# $TMPDIR preserving repo-relative paths — restorable with --restore until
# --empty is run. The ONLY `rm` in this script is scoped strictly inside
# the trash dir.
#
# Usage:
#   ai-trash.sh [--dry-run] <repo-relative-path>...   stage files for deletion
#   ai-trash.sh --list                                show trash contents
#   ai-trash.sh --restore [--dry-run] <path>...       restore staged files
#   ai-trash.sh --empty [--dry-run]                   permanently empty the trash
#
# Guards:
#   - rejects absolute paths and `..` components
#   - rejects paths escaping the git worktree
#   - rejects `.`, `/`, and `.git` itself
#   - rejects glob characters (* ? [ ]) — pass explicit paths, one per arg
#   - --empty refuses to touch anything outside the trash dir
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$ROOT" ]] || { echo "Error: not inside a git worktree." >&2; exit 1; }

REPO="$(basename "$ROOT")"
ROOT_REAL="$(cd -P "$ROOT" >/dev/null && pwd -P)"
TMP_BASE="${TMPDIR:-/tmp}"
TRASH_BASE="${TMP_BASE%/}/opencode-trash"
TRASH="$TRASH_BASE/$REPO"

fail() { echo "Error: $*" >&2; exit 1; }

# Canonicalise a repo-relative path; prints absolute path or fails.
resolve() {
  local raw="$1"
  [[ -n "$raw" ]] || fail "empty path argument"
  [[ "$raw" != /* ]] || fail "absolute paths not allowed: $raw"
  [[ "$raw" != "." && "$raw" != "./" ]] || fail "refusing worktree root"
  case "$raw" in
    *".."* ) fail "\`..\` components not allowed: $raw" ;;
    *\**|*\?*|*\[* ) fail "glob characters not allowed — pass explicit paths: $raw" ;;
    .git|.git/* ) fail "refusing to touch .git: $raw" ;;
  esac
  local abs="$ROOT/$raw"
  # Resolve symlinks in existing parents (portable: no `realpath -m` on macOS).
  # `..` is already rejected above, so a lexical join can only escape via a
  # symlink — resolving the parent with pwd -P closes that.
  local parent_dir
  parent_dir="$(dirname "$abs")"
  if [[ -d "$parent_dir" ]]; then
    abs="$(cd -P "$parent_dir" >/dev/null && pwd -P)/$(basename "$abs")"
  fi
  # Re-anchor: ROOT itself may contain symlinks (/tmp on macOS, etc.).
  local root_real="$ROOT_REAL"
  [[ "$abs" == "$root_real/"* ]] || fail "path escapes worktree: $raw"
  printf '%s' "$abs"
}

cmd_list() {
  if [[ ! -d "$TRASH" ]]; then
    echo "Trash empty (no dir $TRASH)."
    return 0
  fi
  echo "Trash for $REPO ($TRASH):"
  (cd "$TRASH" && find . -mindepth 1 | sort)
}

cmd_restore() {
  local dry=0
  if [[ "${1:-}" == "--dry-run" ]]; then dry=1; shift; fi
  [[ $# -gt 0 ]] || fail "Usage: ai-trash.sh --restore [--dry-run] <repo-relative-path>..."
  for raw in "$@"; do
    abs="$(resolve "$raw")"
    rel="${abs#$ROOT_REAL/}"
    if [[ ! -e "$TRASH/$rel" && ! -L "$TRASH/$rel" ]]; then
      fail "not in trash: $rel"
    fi
    if [[ $dry -eq 1 ]]; then
      echo "would restore $rel"
      continue
    fi
    if [[ -e "$abs" || -L "$abs" ]]; then
      fail "destination exists, refusing to overwrite: $rel"
    fi
    mkdir -p "$(dirname "$abs")"
    mv -- "$TRASH/$rel" "$abs"
    echo "restored $rel"
  done
}

cmd_trash() {
  local dry=0
  if [[ "${1:-}" == "--dry-run" ]]; then dry=1; shift; fi
  [[ $# -gt 0 ]] || fail "Usage: ai-trash.sh [--dry-run] <repo-relative-path>..."
  for raw in "$@"; do
    abs="$(resolve "$raw")"
    rel="${abs#$ROOT_REAL/}"
    [[ -e "$abs" || -L "$abs" ]] || fail "no such file: $raw"
    if [[ $dry -eq 1 ]]; then
      echo "would trash $rel"
      continue
    fi
    mkdir -p "$TRASH/$(dirname "$rel")"
    mv -- "$abs" "$TRASH/$rel"
    echo "trashed $rel"
  done
  echo ""
  echo "=== git status --short ==="
  git -C "$ROOT" status --short || true
  echo ""
  echo "Trash: $TRASH — restorable via 'ai-trash.sh --restore <path>';"
  echo "permanent: 'ai-trash.sh --empty' (rm scoped to the trash dir only)."
}

cmd_empty() {
  local dry=0
  if [[ "${1:-}" == "--dry-run" ]]; then dry=1; shift; fi
  [[ -d "$TRASH" ]] || { echo "Trash already empty (no dir $TRASH)."; return 0; }
  # Hard scope: refuse unless TRASH is a direct child of the trash base.
  [[ "$TRASH" == "$TRASH_BASE/"* && "$TRASH" != "$TRASH_BASE" ]] \
    || fail "refusing to empty outside trash dir: $TRASH"
  local n
  n="$(cd "$TRASH" && find . -mindepth 1 | wc -l | tr -d ' ')"
  echo "Emptying trash for $REPO: $n item(s) in $TRASH"
  if [[ $dry -eq 1 ]]; then
    (cd "$TRASH" && find . -mindepth 1 | sort)
    echo "[dry-run] nothing removed."
    return 0
  fi
  (cd "$TRASH" && find . -mindepth 1 | sort)
  rm -rf -- "$TRASH"
  echo "Trash emptied (permanent)."
}

case "${1:-}" in
  --list) shift; cmd_list "$@" ;;
  --restore) shift; cmd_restore "$@" ;;
  --empty) shift; cmd_empty "$@" ;;
  *) cmd_trash "$@" ;;
esac
