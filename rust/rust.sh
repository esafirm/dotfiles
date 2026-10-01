## to make it work we should install rust first using rustup with:
## ```
## $ brew install rustup
## $ rustup-init
## ```
export PATH="$HOME/.cargo/bin:$PATH"

CARGO_ENV="$HOME/.cargo/env"
if [ -f "$CARGO_ENV" ]; then
    source "$CARGO_ENV"
fi
