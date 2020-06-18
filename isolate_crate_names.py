#!/usr/bin/env python

import sys

def iso(
    in_file,
    out_file):
    # Read in list and populate array
    crates = []
    i = open(in_file, 'r')
    for line in i:
        pathparts = line.split("/")
        crate = pathparts[len(pathparts) - 2]
        crates.append(crate)
        crates.append("\n")
    # Write to output file
    o_clear = open(out_file, 'w')
    o_clear.write("")
    o = open(out_file, 'a')
    for crate in crates:
        o.write(crate)
    # Cleanup
    i.close()
    o.close()

if __name__ == "__main__":
    in_file = sys.argv[1]
    out_file = sys.argv[2]
    iso(
        in_file,
        out_file
    )
