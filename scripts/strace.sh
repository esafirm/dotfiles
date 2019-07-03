#!/usr/bin/env bash

## Running systrace in ANDROID_HOME
## Result will be printed out in the stdout, if not please go to systrace dir
strace() {
    SYSTRACE_DIR=$ANDROID_HOME/platform-tools/systrace
    cd $SYSTRACE_DIR
    python2.7 systrace.py sched freq idle am wm gfx view binder_driver hal dalvik camera input res
}