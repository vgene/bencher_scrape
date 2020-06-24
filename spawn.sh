#!/bin/bash

cp /benchdata/.bashrc ~/.bashrc
cp /benchdata/.bash_profile ~/.bash_profile
source ~/.bashrc

cd /benchdata/rust/bencher_scrape

OUTNAME="cloudlab-output"

# Pre-compile
#./bench.sh -c -o "$OUTNAME"

# Run
./bench.sh -b -r 2 -o "$OUTNAME"
