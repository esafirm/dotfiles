## to make it work we should install rust first using rustup with:
## ```
## $ brew install rustup
## $ rustup-init
## ```
CARGO_ENV=$HOME/.cargo/env
if [ -f $CARGO_ENV ]; then
    source $HOME/.cargo/env
else
    vecho "> Rust is not installed"
fi
