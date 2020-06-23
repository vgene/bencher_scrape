#!/bin/bash

# *****DEFAULTS*****

# Don't scrape
scrape=0
# Don't bench
bench=0
# Don't test
tst=0
# Don't pre-compile
comp=0
# Only one run
runs=1
# Some descriptive name of this invocation
name="sanity"
output="output"

UNMOD_ENV="nightly-2020-05-07-x86_64-unknown-linux-gnu"
NOBC_ENV="nobc"
NOBC_SL_ENV="nobc+sl"
SAFELIB_ENV="safelib"

TCHAIN_ENVS=( "$UNMOD_ENV" "$NOBC_ENV" "$NOBC_SL_ENV" "$SAFELIB_ENV" )

# Optimization Level Management
# OPTFLAGS="-C no-prepopulate-passes -C passes=name-anon-globals" # NO OPTS at all, stricter than opt-level=0
OPTFLAGS="-C opt-level=3"

# Debug Management
DBGFLAGS="-C debuginfo=2"

# LTO Flags
LTOFLAGS_A="-C embed-bitcode=no"

RUSTFLAGS=""$OPTFLAGS" "$DBGFLAGS"" # "$LTOFLAGS_A""

# Command to use below
RUSTC_CMD="cargo rustc --release --bench -- --emit=llvm-bc"

# *****COMMAND-LINE ARGS*****

usage () {
    echo ""
    echo "Usage: $0 [-s] [-b] [-t] [-c <pre-comp>] [-n <out-label>] [-o <dir-label>] [-r <num-runs>]"
    echo "   -s               Scrape reverse dependencies and download locally [default = off]."
    echo "   -b               Bench crates with all three versions of rustc [default = off]."
    echo "   -t               Test crates with all three versions of rustc [default = off]."
    echo "   -c               Compile crate benchmarks only (without running) with all three"
    echo "                      versions of rustc; for large-scale benchmark experiment"
    echo "                      [default = off]."
    echo "   -n <out-label>   How to label the output files of this invocation."
    echo "   -o <dir-label>   How to label the output directory of this invocation."
    echo "   -r <num-runs>    How many runs to execute [default = 1]."
    echo ""
}

# Parse commandline arguments
while getopts "sbtcn:o:r:h" opt
do
    case "$opt" in
    s)
        scrape=1
        ;;
    b)
        bench=1
        ;;
    t)
        tst=1
        ;;
    c)
        comp=1
	;;
    n)
        name="$OPTARG"
        ;;
    o)
	output="$OPTARG"
	;;
    r)
	runs="$(($OPTARG))"
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

# Between consecutive runs of this script, want to
# re-randomize and also create distinct output dirs
for i in $(seq 1 $runs)
do

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
if [ "$runs" -gt 1 -a "$comp" -eq 0 ]
then
    OUTPUT="$output-$i"
else
    OUTPUT="$output"
fi
TARGET="target"

# *****BENCH*****

if [ "$bench" -eq 1 -o "$comp" -eq 0 ]
then
    for env in ${TCHAIN_ENVS[@]}
    do
        precomp_outdir="$output/$TARGET-$env-$SUFFIX"
        benchres="$OUTPUT/$env-$SUFFIX.bench"
        rustup override set $env
        for d in ${RANDDIRS[@]}
        do
            cd "$d"
            if [ "$comp" -eq 1 ]
            then
                cargo clean
                mkdir -p "$OUTPUT"
                RUSTFLAGS=$RUSTFLAGS cargo bench --no-run
            else
                mkdir -p "$OUTPUT"
                # If pre-compiled, only need one version of the compiled code
                # but want to save the multiple run results in distinct locations
                mv "$precomp_outdir" "$TARGET"
                RUSTFLAGS=$RUSTFLAGS cargo bench > "$benchres"
            fi
            mv "$TARGET" "$precomp_outdir"
            cd "$ROOT"
        done
    done
fi

# *****TEST*****

if [ "$tst" -eq 1 ]
then
    for env in ${TCHAIN_ENVS[@]}
    do
        outdir="$OUTPUT/$TARGET-$env-$SUFFIX"
        testres="$OUTPUT/$env-$SUFFIX.test"
        rustup override set $env
        for d in ${RANDDIRS[@]}
        do
            cd "$d"
            # Avoid re-compiling if possible
            if [ "$bench" -eq 1 ]
            then
                mv "$outdir" "$TARGET"
            else
                cargo clean && mkdir -p "$OUTPUT"
            fi
            RUSTFLAGS=$RUSTFLAGS cargo test > "$testres"
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
SCRIPT_NAME="gnuplot-script"

if [ "$comp" -eq 1 ]
then
    for d in ${RANDDIRS[@]}
    do
        cd "$d"
        mkdir -p "$PWD/$OUTPUT"
        # Gnuplot Script: Copy into crate directories for easier use
        cp "$ROOT/$SCRIPT_NAME" "$PWD/$OUTPUT/$SCRIPT_NAME"
        cd "$ROOT"
    done
fi

if [ "$bench" -eq 1 ]
then
    for env in ${TCHAIN_ENVS[@]}
    do
        if [[ "$env" == "$UNMOD_ENV" ]]
        then
            continue
        fi
        unmod_benchres="$OUTPUT/$UNMOD_ENV-$SUFFIX.bench"
        DIFF_BENCH="$BENCH_NAME-$env.diff"
        for d in ${RANDDIRS[@]}
        do
            this_benchres="$OUTPUT/$env-$SUFFIX.bench"
            cd "$d"
            # Simple benchmark diff: Low effort to read if small set of data
            diff "$unmod_benchres" "$this_benchres" > "$DIFF_BENCH"
            cd "$ROOT"
        done
    done
    DATA_BENCH="$BENCH_NAME.data"
    for d in ${RANDDIRS[@]}
    do
        nobc_benchres="$OUTPUT/$NOBC_ENV-$SUFFIX.bench"
        nobcsl_benchres="$OUTPUT/$NOBC_SL_ENV-$SUFFIX.bench"
        safelib_benchres="$OUTPUT/$SAFELIB_ENV-$SUFFIX.bench"
        cd "$d"
        # Run Data Aggregator for Gnuplot: Better visualization for larger sets of data
        # (hard-coded for 3 input files atm)
        python3 "$AGGLOC" "$PWD/$DATA_BENCH" "$unmod_benchres" "$nobc_benchres" "$nobcsl_benchres" "$safelib_benchres"
        cd "$ROOT"
    done
fi

# Simple test diff: check if test failures are specific to the modified rustc or not
if [ "$tst" -eq 1 ]
then
    for env in ${TCHAIN_ENVS[@]}
    do
        if [[ "$env" == "$UNMOD_ENV" ]]
        then
            continue
        fi
        unmod_testres="$OUTPUT/$UNMOD_ENV-$SUFFIX.test"
        DIFF_TEST="$TEST_NAME-$env.diff"
        for d in ${RANDDIRS[@]}
        do
            this_testres="$OUTPUT/$env-$SUFFIX.test"
            cd "$d"
            diff "$unmod_testres" "$this_testres" > "$DIFF_TEST"
            cd "$ROOT"
        done
    done
fi

done
