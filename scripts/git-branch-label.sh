#!/bin/sh
# Branch labels via branch.<name>.description
#   git label "next sprint"   set label for current branch
#   git label                 show label of current branch
#   git labels                list branches that have labels

if [ "$1" = "list" ]; then
    git branch --format='%(refname:short)' | while read -r b; do
        label=$(git config "branch.$b.description" 2>/dev/null) && echo "$b ($label)"
    done
    exit 0
fi

ref=$(git symbolic-ref --short HEAD 2>/dev/null) || { echo "not on a branch" >&2; exit 1; }

if [ -n "$1" ]; then
    git config "branch.$ref.description" "$*"
else
    git config "branch.$ref.description"
fi
