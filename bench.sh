#!/bin/bash

RUSTC_UNMOD="$HOME/.cargo"
RUSTC_MOD="$HOME/.cargo-mod"
ROOT="$PWD"
SUBDIRS="$ROOT/crates/clones/*/"

UNMOD_RES="unmod.bench"
MOD_RES="mod.bench"

# Step 1: Download reverse dependencies of `bencher` crate

cd crates/ && scrapy crawl crates && cd ..

# Step 2: Build and bench with unmodified rustc (slice bounds checks still on)

export CARGO_BUILD_RUSTC="$RUSTC_UNMOD/bin/rustc"
for d in $SUBDIRS
do
    cd "$d" && cargo clean && cargo bench > UNMOD_RES && mv "target/" "target-unmod/" && cd "$ROOT"
done

# Step 3: Build and bench with modified rustc (slice bounds checks now OFF)

export CARGO_BUILD_RUSTC="$RUSTC_MOD/bin/rustc"
for d in $SUBDIRS
do
    cd "$d" && cargo clean && cargo bench > MOD_RES && mv "target/" "target-mod/" && cd "$ROOT"
done

# Optional Step 4: conglomerate results

AGGLOC="$ROOT/aggregate_bench.py"

echo "\n" > "$ROOT/bench.data"
for d in $SUBDIRS
do
    #cd "$d" && diff "$UNMOD_RES" "$MOD_RES" > "bench.diff" && cd "$ROOT"
    cd "$d" && python3 "$AGGLOC" && cd "$ROOT"
    #cat "$d/bench.data" >> "$ROOT/bench.data"
done
