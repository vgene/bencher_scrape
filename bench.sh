#!/bin/bash

# *****DEFAULTS*****

# Don't scrape
scrape=0
# Don't bench
bench=0
# Don't test
tst=0
# Some descriptive name of this invocation
name="sanity"
output="output"

# *****COMMAND-LINE ARGS*****

usage () {
    echo ""
    echo "Usage: $0 [-s] [-c <tchain-name>] [-b] [-t] [-n <out-label>] [-o <dir-label>]"
    echo "   -s               scrape reverse dependencies and download locally  [default = off]"
    echo "   -c <tchain-name> adds this rustup toolchain name to the list of toolchains to use"
    echo "                      for the benchmarks and/or tests - note that in order to use the"
    echo "                      unmodified rustc specified in this repository's 'rust-toolchain'"
    echo "                      file you must pass: '-' as the <tchain-name>"
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

# *****PRE-PROCESS*****

# Get list of crates to run on and randomize their order
ROOT="$PWD"
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

# *****SCRAPE*****

if [ "$scrape" -eq 1 ]
then
    cd crates/ && scrapy crawl crates && cd ..
fi

# Initialize other helpful variables (mostly for naming output files)
SUFFIX="$name"
OUTPUT="$output"
TARGET="target"

# *****BENCH*****

if [ "$bench" -eq 1 ]
then
    for tchain in ${TCHAINS[@]}
    do
        outdir="$OUTPUT/$TARGET-$tchain-$SUFFIX"
        benchres="$OUTPUT/$tchain-$SUFFIX.bench"
        if [[ "$tchain" == "-" ]]
        then
            tc=""
        else
            tc="+$tchain"
        fi
        for d in ${RANDDIRS[@]}
        do
            cd "$d"
            cargo clean
            mkdir -p "$OUTPUT"
            cargo "$tc" bench > "$benchres"
            mv "$TARGET" "$outdir"
            cd "$ROOT"
        done
    done
fi

# *****TEST*****

if [ "$tst" -eq 1 ]
then
    for tchain in ${TCHAINS[@]}
    do
        outdir="$OUTPUT/$TARGET-$tchain-$SUFFIX"
        testres="$OUTPUT/$tchain-$SUFFIX.test"
        if [[ "$tchain" == "-" ]]
        then
            tc=""
        else
            tc="+$tchain"
        fi
        for d in ${RANDDIRS[@]}
        do
            cd "$d"
            # Avoid re-compiling if possible
            if [ "$bench" -eq 1]
            then
                mv "$outdir" "$TARGET"
                cargo "$tc" test > "$testres"
            else
                cargo clean && mkdir -p "$OUTPUT"
                cargo "$tc" test > "$testres"
            fi
            # Store back
            mv "$TARGET" "$outdir"
            cd "$ROOT"
        done
    done
fi

# *****AGGREGATE RESULTS*****

AGGLOC="$ROOT/aggregate_bench.py"
BENCH_NAME="$OUTPUT/bench-$SUFFIX"
TEST_NAME="$OUTPUT/test-$SUFFIX"
DATA_BENCH="$BENCH_NAME.data"
DIFF_BENCH="$BENCH_NAME.diff"
DIFF_TEST="$TEST_NAME.diff"
SCRIPT_NAME="gnuplot-script"

if [ "$bench" -eq 1 ]
then
    for tchain in ${TCHAINS[@]}
    do
        if [[ "$tchain" == "-" ]]
        then
            continue
        fi
        unmod_benchres="$OUTPUT/--$SUFFIX.bench"
        for d in ${RANDDIRS[@]}
        do
            this_benchres="$OUTPUT/$tchain-$SUFFIX.bench"
            cd "$d"
            # Simple benchmark diff: Low effort to read if small set of data
            diff "$unmod_benchres" "$this_benchres" > "$DIFF_BENCH"
            # Run Data Aggregator for Gnuplot: Better visualization for larger sets of data
            python3 "$AGGLOC" "$PWD/$DATA_BENCH" "$unmod_benchres" "$this_benchres"
            # Gnuplot Script: Copy into crate directories for easier use
            cp "$ROOT/$SCRIPT_NAME" "$PWD/$SCRIPT_NAME"
            cd "$ROOT"
        done
    done
fi

# Simple test diff: check if test failures are specific to the modified rustc or not
if [ "$tst" -eq 1 ]
then
    for tchain in ${TCHAINS[@]}
    do
        if [[ "$tchain" == "-" ]]
        then
            continue
        fi
        unmod_testres="$OUTPUT/--$SUFFIX.test"
        for d in ${RANDDIRS[@]}
        do
            this_testres="$OUTPUT/$tchain-$SUFFIX.test"
            cd "$d"
            diff "$unmod_testres" "$this_testres" > "$DIFF_TEST"
            cd "$ROOT"
        done
    done
fi
