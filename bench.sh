#!/bin/bash

# DEFAULTS

# Don't scrape
scrape=0
# Don't bench
bench=0
# Don't test
tst=0
# Some descriptive name of this invocation
name="sanity"
output="output"

usage () {
    echo ""
    echo "Usage: $0 [-s] [-c <tchain-name>] [-b] [-t] [-n <out-label>] [-o <dir-label>]"
    echo "   -s               scrape reverse dependencies and download locally  [default = off]"
    echo "   -c <tchain-name> adds this rustup toolchain name to the list of toolchains to use"
    echo "                      for the benchmarks and/or tests - note that in order to use the"
    echo "                      unmodified rustc specified in the 'rust-toolchain' file you must"
    echo "                      pass an empty <tchain-name>"
    echo "   -b               bench all crates with all three versions of rustc"
    echo "   -t               test all crates with all three versions of rustc"
    echo "   -n <out-label>   what to label the output files of this invocation as"
    echo "   -o <dir-label>   what to label the output directory of this invocation as"
    echo ""
}

# Parse commandline arguments
TCHAINS=()
while getopts "sc:btn:o:h" opt
do
    case "$opt" in
    s)
        scrape=1
        ;;
    c)
	TCHAINS=( "${TCHAINS[@]}" "$OPTARG" )
	;;
    b)
        bench=1
        ;;
    t)
        tst=1
        ;;
    n)
        name="$OPTARG"
        ;;
    o)
	output="$OPTARG"
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

#RUSTC_UNMOD="$HOME/.cargo"
#RUSTC_MOD="$HOME/.cargo-mod"
ROOT="$PWD"

# Get list of crates to run on and randomize their order
SUBDIRS="$ROOT/crates/crates/*/"
DIRLIST="dirlist"
RAND_DIRLIST="rand-dirlist"
RAND_SCRIPT="randomize.py"

rm "$DIRLIST"
for d in ${SUBDIRS[@]}
do
    echo "$d" >> "$DIRLIST"
done

python3 "$RAND_SCRIPT" "$DIRLIST" "$RAND_DIRLIST"

# Parse randomized list as array

RANDDIRS=()
while read -r line
do
    RANDDIRS=( "${RANDDIRS[@]}" "$line" )
done < "$RAND_DIRLIST"

# Pre-processing done, start running

# Download reverse dependencies of `bencher` crate

if [ "$scrape" -eq 1 ]
then
    cd crates/ && scrapy crawl crates && cd ..
fi

# Initialize other helpful variables (mostly for naming output files)
SUFFIX="$name"
OUTPUT="$output"

#UNMOD_NAME="unmod-$SUFFIX"
#MOD_NAME="mod-$SUFFIX"

#UNMOD_RES="$OUTPUT/$UNMOD_NAME.bench"
#MOD_RES="$OUTPUT/$MOD_NAME.bench"
#UNMOD_TESTS="$OUTPUT/$UNMOD_NAME.tests"
#MOD_TESTS="$OUTPUT/$MOD_NAME.tests"

TARGET="target"

#UNMOD_TARGET_DIR="$OUTPUT/$TARGET-$UNMOD_NAME"
#MOD_TARGET_DIR="$OUTPUT/$TARGET-$MOD_NAME"

# BENCH

if [ "$bench" -eq 1 ]
then
    for tchain in ${TCHAINS[@]}
    do
        for d in ${RANDDIRS[@]}
        do
            #echo "$d/$tchain-$SUFFIX"
            cd "$d" && cargo clean && mkdir -p "$OUTPUT" && cargo "+$tchain" bench > "$OUTPUT/$tchain-$SUFFIX.bench" && mv "$TARGET" "$OUTPUT/$TARGET-$tchain-$SUFFIX" && cd "$ROOT"
        done
    done
fi

# TEST

if [ "$tst" -eq 1 ]
then
    for tchain in ${TCHAINS[@]}
    do
        for d in ${RANDDIRS[@]}
        do
            # Avoid re-compiling if possible
            if [ "$bench" -eq 1]
            then
                cd "$d" && mv "$OUTPUT/$TARGET-$tchain-$SUFFIX" "$TARGET" && cargo "+$tchain" test > "$OUTPUT/$tchain-$SUFFIX.test" && mv "$TARGET" "$OUTPUT/$TARGET-$tchain-$SUFFIX" && cd "$ROOT"
            else
                cd "$d" && cargo clean && mkdir -p "$OUTPUT" && cargo "+$tchain" test > "$OUTPUT/$tchain-$SUFFIX.test" && mv "$TARGET" "$OUTPUT/$TARGET-$tchain-$SUFFIX" && cd "$ROOT"
            fi
        done
    done
fi

# AGGREGATE RESULTS

AGGLOC="$ROOT/aggregate_bench.py"
BENCH_NAME="$OUTPUT/bench-$SUFFIX"
TEST_NAME="$OUTPUT/test-$SUFFIX"
DATA_BENCH="$BENCH_NAME.data"
DIFF_BENCH="$BENCH_NAME.diff"
DIFF_TEST="$TEST_NAME.diff"
SCRIPT_NAME="gnuplot-script"

if [ "$bench" -eq 1 ]
then
    # Simple benchmark diff: Low effort to read if small set of data
    for d in ${RANDDIRS[@]}
    do
        cd "$d" &&
#            diff "$UNMOD_RES" "$MOD_RES" > "$DIFF_BENCH" && 
            cd "$ROOT"
    done
    
    # Run Data Aggregator for Gnuplot: Better visualization for larger sets of data
    for d in ${RANDDIRS[@]}
    do
        cd "$d" &&
#            python3 "$AGGLOC" "$PWD/$DATA_BENCH" "$UNMOD_RES" "$MOD_RES" &&
            cd "$ROOT"
    done
    
    # Gnuplot Script: Copy into crate directories for easier use
    for d in ${RANDDIRS[@]}
    do
        cd "$d" &&
            cp "$ROOT/$SCRIPT_NAME" "$PWD/$SCRIPT_NAME" &&
            cd "$ROOT"
    done
fi

# Simple test diff: check if test failures are specific to the modified rustc or not
if [ "$tst" -eq 1 ]
then
    for d in ${RANDDIRS[@]}
    do
        cd "$d" &&
#            diff "$UNMOD_TESTS" "$MOD_TESTS" > "$DIFF_TEST" && 
            cd "$ROOT"
    done
fi
