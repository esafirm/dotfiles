#!/usr/bin/env bash

strace() {
    SYSTRACE_DIR=$ANDROID_HOME/platform-tools/systrace
    cd $SYSTRACE_DIR
    python2.7 systrace.py sched freq idle am wm gfx view binder_driver hal dalvik camera input res
}