## This file run necessary setup for ZSH theme to works

BULLETTRAIN_DIR_BG="blue"
BULLETTRAIN_DIR_FG="white"
BULLETTRAIN_CONTEXT_DEFAULT_USER=$(whoami)
BULLETTRAIN_PROMPT_ORDER=(
    time
    status
    custom
    context
    dir
    #perl
    # ruby
    virtualenv
    #nvm
    #aws
    #go
    #elixir
    git
    #hg
    cmd_exec_time
)
