#!/bin/bash

# Rustup environment management
UNMOD_ENV="custom"
MOD_ENV="natalie"

# Optimization Level Management
# OPTFLAGS="-C no-prepopulate-passes -C passes=name-anon-globals" # NO OPTS at all, stricter than opt-level=0
OPTFLAGS="-C opt-level=2"

# Debug Management
DBGFLAGS="-C debuginfo=2"

# LTO Flags
LTOFLAGS_A="-C embed-bitcode=yes"
LTOFLAGS_B="-C lto=fat"

RUSTFLAGS=""$OPTFLAGS" "$DBGFLAGS" "$LTOFLAGS_A""
RUSTC_EXTRA_FLAGS="-- "$LTOFLAGS_B"" 

RUSTC_CMD="cargo rustc --release --bench arraystring -- --emit=llvm-bc $LTOFLAGS_B"
lprof=1

# Defaults: 

# Don't scrape
scrape=0
# Bench BOTH unmod + mod
comp="n"
# Don't run tests
tstcomp="n"
# Some descriptive name of this invocation
name="sanity"
output="output"

usage () {
    echo ""
    echo "Usage: $0 [-s] [-b <rustc-optn>] [-t] [-d <dir-symbol>] [-n <out-label>]"
    echo "   -s               scrape reverse dependencies and download locally  [default = off]"
    echo "   -b <rustc-optn>  bench crates with one of the following options:"
    echo "                      'u' = unmodified rustc ONLY"
    echo "                      'm' = modified rustc ONLY"
    echo "                      'b' = both unmodified and modified rustc"
    echo "                      'n' = don't run benchmarks                      [default]"
    echo "   -t <rustc-optn>  test crates with one of the following options:"
    echo "                      'u' = unmodified rustc ONLY"
    echo "                      'm' = modified rustc ONLY"
    echo "                      'b' = both unmodified and modified rustc"
    echo "                      'n' = don't run tests                           [default]"
    echo "   -n <out-label>   what to label the output files of this invocation as"
    echo "   -o <dir-label>   what to label the output directory of this invocation as"
    echo ""
}

# Parse commandline arguments
while getopts "sb:t:n:o:h" opt
do
    case "$opt" in
    s)
        scrape=1
        ;;
    b)
        comp="$OPTARG"
        ;;
    t)
        tstcomp="$OPTARG"
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

RUSTC_UNMOD="$HOME/.cargo"
RUSTC_MOD="$HOME/.cargo-mod"
ROOT="$PWD"

# Resolve compiler version(s) for benchmarks
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
n)
    unmod=0
    mod=0
    ;;
*)
    echo ""
    echo "ERROR: Nonexistent compiler-version-option [ "$comp" ] passed to [ -b ]."
    usage
    exit 1
    ;;
esac

# Resolve compiler version(s) for tests
tstunmod=0
tstmod=0
case "$tstcomp" in
u)
    tstunmod=1
    ;;
m)
    tstmod=1
    ;;
b)
    tstunmod=1
    tstmod=1
    ;;
n)
    tstunmod=0
    tstmod=0
    ;;
*)
    echo ""
    echo "ERROR: Nonexistent compiler-version-option [ "$tstcomp" ] passed to [ -t ]."
    usage
    exit 1
    ;;
esac

# Initialize other helpful variables (mostly for naming output files)
SUFFIX="$name"
OUTPUT="$output"

UNMOD_NAME="unmod-$SUFFIX"
MOD_NAME="mod-$SUFFIX"

UNMOD_RES="$OUTPUT/$UNMOD_NAME.bench"
MOD_RES="$OUTPUT/$MOD_NAME.bench"
UNMOD_TESTS="$OUTPUT/$UNMOD_NAME.tests"
MOD_TESTS="$OUTPUT/$MOD_NAME.tests"

TARGET="target"

UNMOD_TARGET_DIR="$OUTPUT/$TARGET-$UNMOD_NAME"
MOD_TARGET_DIR="$OUTPUT/$TARGET-$MOD_NAME"

# SUBDIRS="$ROOT/crates/crates/*/"
SUBDIRS="$ROOT/crates/crates/arrayvec/"

DIRLIST="dirlist"
RAND_DIRLIST="rand-dirlist"
RAND_SCRIPT="randomize.py"

# Get list of crates to run on and randomize their order

rm -f "$DIRLIST"
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

# Step 1: Download reverse dependencies of `bencher` crate

if [ "$scrape" -eq 1 ]
then
    cd crates/ && scrapy crawl crates && cd ..
fi

# Step 2: Build and bench with unmodified rustc (slice bounds checks still on)

if [ "$unmod" -eq 1 ]
then
    cd "$ROOT"
    rustup override set $UNMOD_ENV
    for d in ${RANDDIRS[@]}
    do
        #cd "$d" && cargo clean && mkdir -p "$OUTPUT" && 
        RUSTFLAGS=$RUSTFLAGS cargo bench > "$UNMOD_RES" && mv "$TARGET" "$UNMOD_TARGET_DIR" && cd "$ROOT"
        cd "$d"
        cargo clean
        mkdir -p "$OUTPUT"
        $RUSTC_BENCH_CMD_A 
        echo RUSTFLAGS="$RUSTFLAGS" $RUSTC_CMD
        if [[ "$lprof" -eq 1 ]]
        then
            RUSTFLAGS=$RUSTFLAGS $RUSTC_CMD
            cp ./target/release/deps/*.bc unmod.bc
            make OBJFILES_BC=unmod.bc benchmark.loopProf.out
            mv benchmark.loopProf.out unmod.loopProf.out
        fi
        cd "$ROOT"
    done
fi

# Step 3: Run crate tests when compiled with unmodified rustc

if [ "$tstunmod" -eq 1 ]
then
    cd "$ROOT"
    rustup override set $UNMOD_ENV
    for d in ${RANDDIRS[@]}
    do
        # Can save building the unmodified version twice if step 2 was executed
        if [ "$unmod" -eq 0 ]
        then
            cd "$d" && cargo clean && mkdir -p "$OUTPUT" && cargo test > "$UNMOD_TESTS" && cd "$ROOT"
        else
            cd "$d" && cp -r "$UNMOD_TARGET_DIR" "$TARGET" && cargo test > "$UNMOD_TESTS" && cd "$ROOT"
        fi
    done
fi

# Step 4: Build and bench with modified rustc (slice bounds checks now OFF)

if [ "$mod" -eq 1 ]
then
    cd "$ROOT"
    rustup override set $MOD_ENV
    for d in ${RANDDIRS[@]}
    do
        #cd "$d" && cargo clean && mkdir -p "$OUTPUT" && cargo "+stage2" bench > "$MOD_RES" && mv "$TARGET" "$MOD_TARGET_DIR" && cd "$ROOT"
        cd "$d"
        cargo clean
        mkdir -p "$OUTPUT"
        $RUSTC_BENCH_CMD_A 
        echo RUSTFLAGS=$RUSTFLAGS $RUSTC_CMD
        if [[ "$lprof" -eq 1 ]]
        then
            RUSTFLAGS="$RUSTFLAGS" $RUSTC_CMD
            cp ./target/release/deps/*.bc mod.bc
            make OBJFILES_BC=mod.bc benchmark.loopProf.out
            mv benchmark.loopProf.out mod.loopProf.out
        fi
        cd "$ROOT"
    done
fi

# Step 5: Run crate tests when compiled with modified rustc

if [ "$tstmod" -eq 1 ]
then
    cd "$ROOT"
    rustup override set $MOD_ENV
    for d in ${RANDDIRS[@]}
    do
        # Can save building the modified version twice if step 4 was executed
        if [ "$mod" -eq 0 ]
        then
            cd "$d" && cargo clean && mkdir -p "$OUTPUT" && cargo "+stage2" test > "$MOD_TESTS" && cd "$ROOT"
        else
            cd "$d" && cp -r "$MOD_TARGET_DIR" "$TARGET" && cargo "+stage2" test > "$MOD_TESTS" && cd "$ROOT"
        fi
    done
fi

# Step 6: Conglomerate results

AGGLOC="$ROOT/aggregate_bench.py"
BENCH_NAME="$OUTPUT/bench-$SUFFIX"
TEST_NAME="$OUTPUT/test-$SUFFIX"
DATA_BENCH="$BENCH_NAME.data"
DIFF_BENCH="$BENCH_NAME.diff"
DIFF_TEST="$TEST_NAME.diff"
SCRIPT_NAME="gnuplot-script"

if [ "$unmod" -eq 1 -a "$mod" -eq 1 ]
then
    # Simple benchmark diff: Low effort to read if small set of data
    for d in ${RANDDIRS[@]}
    do
        cd "$d" &&
            diff "$UNMOD_RES" "$MOD_RES" > "$DIFF_BENCH" && 
            cd "$ROOT"
    done
    
    # Run Data Aggregator for Gnuplot: Better visualization for larger sets of data
    for d in ${RANDDIRS[@]}
    do
        cd "$d" &&
            python3 "$AGGLOC" "$PWD/$DATA_BENCH" "$UNMOD_RES" "$MOD_RES" &&
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
if [ "$tstunmod" -eq 1 -a "$tstmod" -eq 1 ]
then
    for d in ${RANDDIRS[@]}
    do
        cd "$d" &&
            diff "$UNMOD_TESTS" "$MOD_TESTS" > "$DIFF_TEST" && 
            cd "$ROOT"
    done
fi
