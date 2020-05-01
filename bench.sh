#!/bin/bash

# Step 1: Download reverse dependencies of `bencher` crate

cd crates/ && scrapy crawl crates && cd ..

# Step 2: Build all downloaded crates (bounds checks on)

RUSTC="$HOME/.cargo_for_bencher"
ROOT="$PWD"
SUBDIRS="$ROOT/crates/clones/*/"

#export CARGO_BUILD_RUSTC="$RUSTC/bin/rustc"
for d in $SUBDIRS
do
    cd "$d" && cargo clean && cargo build --release && cd "$ROOT"
done

# Step 3: Benchmark

for d in $SUBDIRS
do
    cd "$d" && cargo bench --no-fail-fast > bounds_checks_ON.out && cd "$ROOT"
done

# Step 4: Build all downloaded crates (bounds checks off)

#export CARGO_BUILD_RUSTC="$rootpath/../rust_disable_bounds_checks/"
#for d in $subdir
#do
#    cd "$d" && cargo build --release && cd "$rootpath"
#done
#
## Step 5: Benchmark
#
#for d in $subdir
#do
#    cd "$d" && cargo bench --no-fail-fast > bench_res_bc_off && cd "$rootpath"
#done
