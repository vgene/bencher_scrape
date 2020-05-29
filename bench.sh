#!/bin/bash

# Defaults: 

# Don't scrape
scrape=0
# Bench BOTH unmod + mod
unmod=0
mod=0
both=1
# Bench, don't test
tst=0
# Bench the 'inconsistent' subdir
dir="i"
# Some descriptive mame of this invocation
name="sanity-2"

usage () {
    echo "Usage: $0 [-s] [-u] [-m] [-b] [-t] [-d dirname] [-n outname]"
    echo "   -s               scrape reverse dependencies and download locally"
    echo "   -u               only bench crates using unmodified rustc"
    echo "   -m               only bench crates using modified rustc"
    echo "   -b               bench crates using both unmodified and modified rustc"
    echo "   -t               run crate tests after compiling with modified rustc"
    echo "   -d <dir-symbol>  run only for the crates in the specified directory, where"
    echo "                      'b' = better"
    echo "                      'i' = inconsistent"
    echo "                      'w' = worse"
    echo "   -n <out-label>   name to label the output files of this invocation with"
}

# Parse commandline arguments
while getopts "sumbtd:n:h" opt
do
    case "$opt" in
    s) scrape=1
        ;;
    u) unmod=1
        ;;
    m) mod=1
        ;;
    b) both=1
        ;;
    t) tst=1
        ;;
    d) dir="$OPTARG"
        ;;
    n) name="$OPTARG"
        ;;
    h) usage
        exit 0
        ;;
    ?) usage
        exit 1
        ;;
    esac
done

RUSTC_UNMOD="$HOME/.cargo"
RUSTC_MOD="$HOME/.cargo-mod"
ROOT="$PWD"

better="$ROOT/crates/better/*/"
inconsistent="$ROOT/crates/inconsistent/*/"
worse="$ROOT/crates/worse/*/"

if [ "$dir" = "b" ]
then
    SUBDIRS="$better"
    echo "Proceeding in 'better' subdirectory..."
elif [ "$dir" = "i" ]
then
    SUBDIRS="$inconsistent"
    echo "Proceeding in 'inconsistent' subdirectory..."
elif [ "$dir" = "w" ]
then
    SUBDIRS="$worse"
    echo "Proceeding in 'worse' subdirectory..."
else
    echo "Nonexistent directory option [ "$dir" ] specified. Please try again."
    exit 1
fi

SUFFIX="$name"

UNMOD_NAME="unmod-$SUFFIX"
MOD_NAME="mod-$SUFFIX"

UNMOD_RES="$UNMOD_NAME.bench"
MOD_RES="$MOD_NAME.bench"
MOD_TESTS="$MOD_NAME.tests"

TARGET="target"

UNMOD_TARGET_DIR="$TARGET-$UNMOD_NAME"
MOD_TARGET_DIR="$TARGET-$MOD_NAME"

# Step 1: Download reverse dependencies of `bencher` crate

if [ "$scrape" -eq 1 ]
then
    cd crates/ && scrapy crawl crates && cd ..
fi

# Step 2: Build and bench with unmodified rustc (slice bounds checks still on)

if [ "$unmod" -eq 1 -o "$both" -eq 1 ]
then
    export CARGO_BUILD_RUSTC="$RUSTC_UNMOD/bin/rustc"
    for d in $SUBDIRS
    do
        cd "$d" && cargo clean && cargo bench > "$UNMOD_RES" && mv "$TARGET" "$UNMOD_TARGET_DIR" && cd "$ROOT"
    done
fi

# Step 3: Build and bench with modified rustc (slice bounds checks now OFF)

if [ "$mod" -eq 1 -o "$both" -eq 1 ]
then
    export CARGO_BUILD_RUSTC="$RUSTC_MOD/bin/rustc"
    for d in $SUBDIRS
    do
        cd "$d" && cargo clean && cargo bench > "$MOD_RES" && mv "$TARGET" "$MOD_TARGET_DIR" && cd "$ROOT"
    done
fi

# Optional: run tests after building with modified compiler

if [ "$tst" -eq 1]
then
    export CARGO_BUILD_RUSTC="$RUSTC_MOD/bin/rustc"
    for d in $SUBDIRS
    do
        cd "$d" && cargo clean && cargo test > "$MOD_TESTS" && cd "$ROOT"
    done
fi

# Step 4: conglomerate results

AGGLOC="$ROOT/aggregate_bench.py"
BENCH_NAME="bench-$SUFFIX"
DATA_FILE="$BENCH_NAME.data"
DIFF_FILE="$BENCH_NAME.diff"
SCRIPT_NAME="gnuplot-script"

if [ "$unmod" -eq 1 -a "$mod" -eq 1 ] || [ "$both" -eq 1]
then
    # Simple diff: Low effort to read if small set of data
    for d in $SUBDIRS
    do
        cd "$d" &&
            diff "$UNMOD_RES" "$MOD_RES" > "$DIFF_FILE" && 
            cd "$ROOT"
    done
    
    # Data Aggregator for Gnuplot: Better visualization for larger sets of data
    for d in $SUBDIRS
    do
        cd "$d" &&
            python3 "$AGGLOC" "$PWD/$DATA_FILE" "$UNMOD_RES" "$MOD_RES" &&
            cd "$ROOT"
    done
    
    # Gnuplot Script: Copy into crate directories for easier use
    for d in $SUBDIRS
    do
        cd "$d" &&
            cp "$ROOT/$SCRIPT_NAME" "$PWD/$SCRIPT_NAME" &&
            cd "$ROOT"
    done
fi
