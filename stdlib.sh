## A standar library for our dotfiles
## Containing common function that used across the script

isLinux() {
    [ "$(uname)" = "Linux" ]
}

isMac() {
    [ "$(uname)" = "Darwin" ]
}

trim() {
    awk '{$1=$1};1'
}

# Verbose echo
vecho() {
    if [ "$DISABLE_VERBOSE_ECHO" = "true" ]; then return; fi

    echo $1
}
