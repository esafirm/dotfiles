## A standar library for our dotfiles
## Containing common function that used across the script

isLinux() {
    [ "$(uname)" = "Linux" ]
}

isMac() {
    [ "$(uname)" = "Darwin" ]
}

if isMac; then echo "This is BUG SUR"; fi
