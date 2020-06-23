#!/bin/bash

#SSH_NODES=(
#"npopescu@c220g5-111219.wisc.cloudlab.us"
#"npopescu@c220g5-110529.wisc.cloudlab.us"
#"npopescu@c220g5-111031.wisc.cloudlab.us"
#"npopescu@c220g5-110510.wisc.cloudlab.us"
#"npopescu@c220g5-111009.wisc.cloudlab.us"
#"npopescu@c220g5-111019.wisc.cloudlab.us"
#"npopescu@c220g5-111224.wisc.cloudlab.us"
#"npopescu@c220g5-111222.wisc.cloudlab.us"
#"npopescu@c220g5-111228.wisc.cloudlab.us"
#"npopescu@c220g5-111213.wisc.cloudlab.us"
#"npopescu@c220g5-111207.wisc.cloudlab.us"
#"npopescu@c220g5-111014.wisc.cloudlab.us"
#"npopescu@c220g5-110521.wisc.cloudlab.us"
#)

numnodes=13
runs=3

usage () {
    echo ""
    echo "Usage: $0 [-n <num-nodes>] [-r <num-runs>]"
    echo "   -n <num-nodes>   How many nodes were used [default = 13]."
    echo "   -r <num-runs>    How many runs were executed [default = 3]."
    echo ""
}

while getopts "n:r:h" opt
do
    case "$opt" in
    n)
        numnodes="$(($OPTARG))"
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

OUTPUT="cl-output"
LOCAL_OUTPUT="cloudlab-output"
FNAME="bench-sanity"
LOCAL_PATH="$ROOT/crates/crates"
REMOTE_PATH="/mydata/rust/bencher_scrape/crates/crates"

i=0
for node in ${SSH_NODES[@]}
do
    for crate in ${CRATES[@]}
    do
        dir="$LOCAL_PATH/$crate/$LOCAL_OUTPUT"
        mkdir -p "$dir"
        scp "$node:$REMOTE_PATH/$crate/$OUTPUT-1/$FNAME.data" "$dir/$FNAME-$i-1.data"
        scp "$node:$REMOTE_PATH/$crate/$OUTPUT-2/$FNAME.data" "$dir/$FNAME-$i-2.data"
        scp "$node:$REMOTE_PATH/$crate/$OUTPUT-3/$FNAME.data" "$dir/$FNAME-$i-3.data"
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
