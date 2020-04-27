#!/bin/bash

# Step 1: Download reverse dependencies of `bencher` crate

cd crates/ && scrapy crawl crates && cd ..

# Step 2: Build all downloaded crates

rootpath="$PWD"
subdir="./crates/clones/*/"

for d in $subdir
do
    cd "$d" && cargo build --release && cd "$rootpath"
done

# Step 3: Benchmark, normally

for d in $subdir
do
    cd "$d" && cargo bench --no-fail-fast > bench_res_bc_on && cd "$rootpath"
done

# Step 4: Benchmark, Rust bounds checks turned off

for d in $subdir
do
    cd "$d" && cargo bench --no-fail-fast > bench_res_bc_off && cd "$rootpath"
done

