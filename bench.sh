#!/bin/bash

# Defaults: 

# Don't scrape
scrape=0
# Bench BOTH unmod + mod
comp="b"
# Bench, don't test
tst=0
# Bench in all subdirectories
dir="a"
# Some descriptive mame of this invocation
name="sanity-2"

usage () {
    echo -n ""
    echo -n "Usage: $0 [-s] [-b <rustc-optn>] [-t] [-d <dir-symbol>] [-n <out-label>]"
    echo -n "   -s               scrape reverse dependencies and download locally"
    echo -n "   -b <rustc-optn>  bench crates with one of the following options:"
    echo -n "                      'u' = unmodified rustc ONLY"
    echo -n "                      'm' = modified rustc ONLY"
    echo -n "                      'b' = both unmodified and modified rustc"
    echo -n "   -t               run crate tests after compiling with modified rustc,"
    echo -n "                    building the crate if necessary"
    echo -n "   -d <dir-symbol>  run only for the crates in the specified directory, where"
    echo -n "                      'b' = better"
    echo -n "                      'i' = inconsistent"
    echo -n "                      'w' = worse"
    echo -n "                      'a' = all of the above"
    echo -n "   -n <out-label>   what to label the output files of this invocation with"
    echo -n ""
}

# Parse commandline arguments
while getopts "sb:td:n:h" opt
do
    case "$opt" in
    s)
        scrape=1
        ;;
    b)
        comp="$OPTARG"
        ;;
    t)
        tst=1
        ;;
    d)
        dir="$OPTARG"
        ;;
    n)
        name="$OPTARG"
        ;;
    h)
        usage
        exit 0
        ;;
    *)
        usage
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

# Resolve which directory to run in
case "$dir" in
b)
    SUBDIRS="$better"
    ;;
i)
    SUBDIRS="$inconsistent"
    ;;
w)
    SUBDIRS="$worse"
    ;;
a)
    SUBDIRS=("$better" "$inconsistent" "$worse")
    ;;
*)
    echo -n ""
    echo -n "ERROR: Nonexistent directory option [ "$dir" ] passed to [ -d ]."
    usage
    exit 1
    ;;
esac

# Resolve which compiler version(s) to use
unmod=0
mod=0
case "$comp" in
u)
    unmod=1
    ;;
m)
    mod=1
    ;;
b)
    unmod=1
    mod=1
    ;;
*)
    echo -n ""
    echo -n "ERROR: Nonexistent compiler-version-option [ "$comp" ] passed to [ -b ]."
    usage
    exit 1
    ;;
esac

# Initialize other helpful variables (mostly for naming output files)
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

if [ "$unmod" -eq 1 ]
then
    export CARGO_BUILD_RUSTC="$RUSTC_UNMOD/bin/rustc"
    for d in ${SUBDIRS[@]}
    do
        cd "$d" && cargo clean && cargo bench > "$UNMOD_RES" && mv "$TARGET" "$UNMOD_TARGET_DIR" && cd "$ROOT"
    done
fi

# Step 3: Build and bench with modified rustc (slice bounds checks now OFF)

if [ "$mod" -eq 1 ]
then
    export CARGO_BUILD_RUSTC="$RUSTC_MOD/bin/rustc"
    for d in ${SUBDIRS[@]}
    do
        cd "$d" && cargo clean && cargo bench > "$MOD_RES" && mv "$TARGET" "$MOD_TARGET_DIR" && cd "$ROOT"
    done
fi

# Step 4: Run crate tests when compiled with modified rustc

if [ "$tst" -eq 1 ]
then
    export CARGO_BUILD_RUSTC="$RUSTC_MOD/bin/rustc"
    for d in ${SUBDIRS[@]}
    do
        # Can save building the same thing twice if step 3 was executed
        if [ "$mod" -eq 0 ]
        then
            cd "$d" && cargo test > "$MOD_TESTS" && cd "$ROOT"
        else
            cd "$d" && cp -r "$MOD_TARGET_DIR" "$TARGET" && cargo test > "$MOD_TESTS" && cd "$ROOT"
        fi
    done
fi

# Step 5: Conglomerate results

AGGLOC="$ROOT/aggregate_bench.py"
BENCH_NAME="bench-$SUFFIX"
DATA_FILE="$BENCH_NAME.data"
DIFF_FILE="$BENCH_NAME.diff"
SCRIPT_NAME="gnuplot-script"

if [ "$unmod" -eq 1 -a "$mod" -eq 1 ]
then
    # Simple diff: Low effort to read if small set of data
    for d in ${SUBDIRS[@]}
    do
        cd "$d" &&
            diff "$UNMOD_RES" "$MOD_RES" > "$DIFF_FILE" && 
            cd "$ROOT"
    done
    
    # Data Aggregator for Gnuplot: Better visualization for larger sets of data
    for d in ${SUBDIRS[@]}
    do
        cd "$d" &&
            python3 "$AGGLOC" "$PWD/$DATA_FILE" "$UNMOD_RES" "$MOD_RES" &&
            cd "$ROOT"
    done
    
    # Gnuplot Script: Copy into crate directories for easier use
    for d in ${SUBDIRS[@]}
    do
        cd "$d" &&
            cp "$ROOT/$SCRIPT_NAME" "$PWD/$SCRIPT_NAME" &&
            cd "$ROOT"
    done
fi
