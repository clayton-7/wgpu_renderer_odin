#!/usr/bin/bash

debug_flag=""

if [ -n "$1" ]; then
    export WGPU_ENABLE_VALIDATION=1
    export RUST_BACKTRACE=full
fi

odin run src $1 $debug_flag -out:force
