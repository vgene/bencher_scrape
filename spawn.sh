#!/bin/bash

OUTNAME="cl-output"

# Pre-compile
./bench.sh -c -o "$OUTNAME"

# Run
./bench.sh -b -r 2 -o "$OUTNAME"
