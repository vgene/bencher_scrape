#!/bin/bash

cp bashrc ~/.bashrc
cp bash_profile ~/.bash_profile
source ~/.bashrc

OUTNAME="cloudlab-output-lto"

# Pre-compile
#./bench.sh -c -o "$OUTNAME"

# Run
./bench.sh -b -r 2 -o "$OUTNAME"
