#!/bin/bash

numnodes=16
runs=2

PRECOMP_NODE="npopescu@c220g5-111012.wisc.cloudlab.us"

SSH_NODES=(
""
""
""
""
""
""
""
""
""
""
""
""
""
""
""
""
)

# Total runs per crate per toolchain = 32

# Parse paths to get concise crate names
ROOT="$PWD"
SUBDIRS="$ROOT/crates/crates/*/"
DIRLIST="dirlist"
CRATELIST="cratelist"
ISO_SCRIPT="isolate_crate_names.py"

if [ -f "$DIRLIST" ]
then
    rm "$DIRLIST"
fi
touch "$DIRLIST"

for d in ${SUBDIRS[@]}
do
    echo "$d" >> "$DIRLIST"
done

if [ -f "$CRATELIST" ]
then
    rm "$CRATELIST"
fi
touch "$CRATELIST"

python3 "$ISO_SCRIPT" "$DIRLIST" "$CRATELIST"

CRATES=()
while read -r line
do
    CRATES=( "${CRATES[@]}" "$line" )
done < "$CRATELIST"

# Start copying over pre-compilations

ROOT="$PWD"
LOCAL_PATH="$ROOT/crates/crates"
REMOTE_PATH="/mydata/rust/bencher_scrape/crates/crates"
TRGT_UNMOD="target-nightly-2020-05-07-x86_64-unknown-linux-gnu-sanity"
TRGT_NOBC="target-nobc-sanity"
TRGT_NOBCSL="target-nobc+sl-sanity"
TRGT_SAFELIB="target-safelib-sanity"
OUTPUT="output"

for crate in ${CRATES[@]}
do
#    rm -r "$LOCAL_PATH/$crate/$OUTPUT/"
    scp -r "$PRECOMP_NODE:$REMOTE_PATH/$crate/$OUTPUT/" "$LOCAL_PATH/$crate/$OUTPUT/"
done

#for node in ${SSH_NODES[@]}
#do
#    for d in ${SUBDIRS[@]}
#    do
#        scp -r "$node:$d/output-1" ""
#        scp -r "$node:$d/output-2" ""
#    done
#done
