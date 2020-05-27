#!/bin/bash

RUSTC_UNMOD="$HOME/.cargo"
RUSTC_MOD="$HOME/.cargo-mod"
ROOT="$PWD"
SUBDIRS="$ROOT/crates/clones/*/"

# All you should have to change between runs
# Should understandably describe data/purpose of run
SUFFIX="sanity"

UNMOD_NAME="unmod-$SUFFIX"
MOD_NAME="mod-$SUFFIX"

UNMOD_RES="$UNMOD_NAME.bench"
MOD_RES="$MOD_NAME.bench"

TARGET="target"

UNMOD_TARGET_DIR="$TARGET-$UNMOD_NAME"
MOD_TARGET_DIR="$TARGET-$MOD_NAME"

# Step 1: Download reverse dependencies of `bencher` crate

#cd crates/ && scrapy crawl crates && cd ..

# Step 2: Build and bench with unmodified rustc (slice bounds checks still on)

#export CARGO_BUILD_RUSTC="$RUSTC_UNMOD/bin/rustc"
#for d in $SUBDIRS
#do
#    cd "$d" && cargo clean && cargo bench > "$UNMOD_RES" && mv "$TARGET" "$UNMOD_TARGET_DIR" && cd "$ROOT"
#done
#
## Step 3: Build and bench with modified rustc (slice bounds checks now OFF)
#
#export CARGO_BUILD_RUSTC="$RUSTC_MOD/bin/rustc"
#for d in $SUBDIRS
#do
#    cd "$d" && cargo clean && cargo bench > "$MOD_RES" && mv "$TARGET" "$MOD_TARGET_DIR" && cd "$ROOT"
#done

# Optional Step 4: conglomerate results

AGGLOC="$ROOT/aggregate_bench.py"
DATA_FILE="bench.data"

BENCH_NAME="bench-$SUFFIX"
DIFF_FILE="$BENCH_NAME.diff"

for d in $SUBDIRS
do
    cd "$d" &&
        mv UNMOD_RES "$UNMOD_RES" && 
        mv MOD_RES "$MOD_RES" &&
        # Low effort to read if small set of data
        diff "$UNMOD_RES" "$MOD_RES" > "$DIFF_FILE" && 
        # Better visualization for larger sets of data
        python3 "$AGGLOC" "./$DATA_FILE" "$UNMOD_RES" "$MOD_RES" &&
        cd "$ROOT"
done
