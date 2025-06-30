#!/usr/bin/bash

BIN_NAME=force
SOURCE_PATH=src
DEBUG_FLAG="-debug -vet-unused-imports -vet-shadowing -vet-using-stmt -vet-using-param -vet-cast -warnings-as-errors -use-separate-modules"

# RUN
if [ -n "$1" ] && [ "$1" = "run" ]; then
    ./$BIN_NAME
    exit 0
fi

[ -f "error.log" ] && rm "error.log"

# DEBUG MODE
if [ -n "$1" ]; then
    export WGPU_ENABLE_VALIDATION=1
    export RUST_BACKTRACE=full
else
    DEBUG_FLAG=""
fi

odin build $SOURCE_PATH $DEBUG_FLAG -out:$BIN_NAME 2> error.log

if [ $? -ne 0 ]; then
    echo "Build failed."
    sed -i 's/^||/  /' error.log
    exit 1
fi

rm "error.log"
exit 0
