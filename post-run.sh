#!/bin/bash

SSH_NODES=(
"npopescu@c220g2-010819.wisc.cloudlab.us"
"npopescu@c220g2-010826.wisc.cloudlab.us"
"npopescu@c220g2-010824.wisc.cloudlab.us"
"npopescu@c220g2-011305.wisc.cloudlab.us"
"npopescu@c220g2-011310.wisc.cloudlab.us"
"npopescu@c220g2-011315.wisc.cloudlab.us"
"npopescu@c220g2-011303.wisc.cloudlab.us"
"npopescu@c220g2-010821.wisc.cloudlab.us"
"npopescu@c220g2-011321.wisc.cloudlab.us"
"npopescu@c220g2-011319.wisc.cloudlab.us"
"npopescu@c220g2-010817.wisc.cloudlab.us"
"npopescu@c220g2-011019.wisc.cloudlab.us"
"npopescu@c220g2-011020.wisc.cloudlab.us"
"npopescu@c220g2-010820.wisc.cloudlab.us"
"npopescu@c220g2-011318.wisc.cloudlab.us"
"npopescu@c220g2-010829.wisc.cloudlab.us"
"npopescu@c220g2-010825.wisc.cloudlab.us"
"npopescu@c220g2-011018.wisc.cloudlab.us"
"npopescu@c220g2-011309.wisc.cloudlab.us"
)

numnodes=19
runs=2
output="cloudlab-output-lto"

usage () {
    echo ""
    echo "Usage: $0 [-n <num-nodes>] [-o <dir-label>] [-r <num-runs>]"
    echo "   -n <num-nodes>   How many nodes were used [default = 13]."
    echo "   -o <dir-label>   How to label the output directory of this invocation."
    echo "   -r <num-runs>    How many runs were executed [default = 3]."
    echo ""
}

while getopts "n:o:r:h" opt
do
    case "$opt" in
    n)
        numnodes="$(($OPTARG))"
        ;;
    r)
        runs="$(($OPTARG))"
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

# Parse paths to get concise crate names
ROOT="$PWD"
SUBDIRS="$ROOT/crates/crates/*/"
DIRLIST="dirlist"
CRATELIST="cratelist"
ISO_SCRIPT="isolate_crate_names.py"

if [ -f "$DIRLIST" ]
then
    rm "$DIRLIST"
fi
touch "$DIRLIST"

for d in ${SUBDIRS[@]}
do
    echo "$d" >> "$DIRLIST"
done

if [ -f "$CRATELIST" ]
then
    rm "$CRATELIST"
fi
touch "$CRATELIST"

python3 "$ISO_SCRIPT" "$DIRLIST" "$CRATELIST"

CRATES=()
while read -r line
do
    CRATES=( "${CRATES[@]}" "$line" )
done < "$CRATELIST"

# Copy actual benchmark data over

OUTPUT="$output"
FNAME="bench-sanity"
LOCAL_PATH="$ROOT/crates/crates"
#LOCAL_PATH="npopescu@sns52.cs.princeton.edu:/disk/scratch2/npopescu/hack/bencher_scrape/crates/crates"
REMOTE_PATH="/benchdata/rust/bencher_scrape/crates/crates"

i=0
for node in ${SSH_NODES[@]}
do
    for crate in ${CRATES[@]}
    do
        loc_dir="$LOCAL_PATH/$crate/$OUTPUT"
        rem_dir="$REMOTE_PATH/$crate/$OUTPUT"
        mkdir -p "$loc_dir"
        for r in $(seq 1 $runs)
        do
            #echo "REMOTE: $node:$rem_dir-$r/$FNAME.data"
            #echo "LOCAL: $loc_dir/$FNAME-$i-$r.data"
            scp "$node:$rem_dir-$r/$FNAME.data" "$loc_dir/$FNAME-$i-$r.data"
        done
    done
    i=$((i+1))
done

# Read out benchmark names from one file and create arrays
#   One array = 1 crate, 1 benchmark (function), 1 rustc version (out of the four)
#
# Note: bench names are kept for graph readability, but they correspond to each 
# of the rows in the bench data file (which is how we will ultimately iterate through 
# the data).

for crate in ${CRATES[@]}
do

# Now that we have the benchmark data locally, transfer control to python (read + number crunch)

CRUNCH="crunch.py"

python3 "$CRUNCH" "$crate" "$FNAME" "$LOCAL_OUTPUT" "$numnodes" "$runs"

done
