#!/usr/bin/env bash

strace() {
    parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
    cd "$parent_path"

    python2.7 systrace/systrace.py sched freq idle am wm gfx view binder_driver hal dalvik camera input res
}