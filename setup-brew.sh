#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/setup-common.sh"
[[ $# -eq 0 ]] || { printf 'Use ./setup.sh --only brew for options such as --dry-run.\n' >&2; exit 2; }

if [[ "$(uname -s)" != Darwin ]]; then
    printf 'Skip Homebrew apps: this package list is for macOS.\n'
    exit 0
fi

# Homebrew may be installed but not on PATH in a fresh shell.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if ! command -v brew >/dev/null 2>&1 && [[ -x "$brew_bin" ]]; then
        export PATH="$(dirname -- "$brew_bin"):$PATH"
    fi
done

if ! command -v brew >/dev/null 2>&1; then
    printf 'Homebrew is missing. Its official installer may request sudo.\n'
    if [[ "$SETUP_DRY_RUN" == 1 ]]; then
        printf '  Would download and run https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh\n'
    else
        installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        /bin/bash -c "$installer"
        if [[ -x /opt/homebrew/bin/brew ]]; then
            export PATH="/opt/homebrew/bin:$PATH"
        else
            export PATH="/usr/local/bin:$PATH"
        fi
    fi
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1

# Non Cask
NONCASK=(
    mitmproxy
    ssh-copy-id
    tmux
    httpie
    wget
    htop
    gifsicle
    cdiff
    tree
    ripgrep
    safe-rm
    tldr
    wd
    git-secret
    go
    tokei
    neovim
    fzf
)

## Cask
## This is now more like a GUI app

CASKS=(
    google-chrome
    visual-studio-code
    transmission
    jetbrains-toolbox
    shiftit
    ghostty
)

for kind in formula cask; do
    if [[ "$kind" == formula ]]; then
        packages=("${NONCASK[@]}")
    else
        packages=("${CASKS[@]}")
    fi
    installed=""
    if command -v brew >/dev/null 2>&1; then
        installed="$(brew list --"$kind" -1)"
    fi
    for item in "${packages[@]}"; do
        if grep -Fxq "$item" <<< "$installed"; then
            printf '  Already installed: %s\n' "$item"
        else
            setup_run brew install --"$kind" "$item"
        fi
    done
done
