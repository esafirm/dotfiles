## Esa's Dotfiles

> This is a readme directed mainly for me.

## Setup

The first thing you should remember is:

1. Generate yout SSH key
2. Update that key to remote repo (Github for dotfiles)
3. Clone dotfiles to `~/dotfiles`

You don't need to:

1. Install oh-my-zsh and set the theme manually
2. Set default login shell to zsh 


So what you've got to do is:

1. Run `./setup-zsh.sh` to setup ZSH
2. Run `./setup.sh` to install everything else

Please read the script first when you want to run it. 

## VScode 

> We do have an instruction in the README file in `/vscode` 

## Android 

> We do have an instruction in the README file in `/android` 

## Vim

For plugin we use [vim-plug](https://github.com/junegunn/vim-plug) and the setup is already included in `setup.sh`

## Manual Setup

Currently, we still need to manually setup this because we haven't found a way to automate it.

- Initliazation of [Cleanshot](https://cleanshot.com/)
## Directory Structure

- `scripts/` — zsh function scripts ONLY (sourced at shell startup via `for file in $DOT/scripts/*; do source $file`). All files here must be valid zsh.
- `kotlin/kscripts/` — Kotlin `.kts` scripts (NOT zsh source-able). Invoked via aliases like `jk='kotlin $DOT/kotlin/kscripts/...'`.
- `bin/` — standalone executables placed on `$PATH`.

> **Rule:** Never put a `.kts`, `.py`, or other non-zsh file in `scripts/` — it will be `source`d by zsh on every terminal start and break shell init.

## Author

esafirm 