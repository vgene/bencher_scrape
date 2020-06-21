#!/usr/bin/env python

import os
import sys
import math
from subprocess import check_output
import numpy


def average(array):
    # Get length of array
    length = len(array)
    arr_sum = 0
    # Calculate sum
    for a in array:
        arr_sum += a
    res = arr_sum / length
    return res


def stddev(array, arr_avg):
    length = len(array)
    sqrs = []
    # Squares of diffs
    for a in array:
        diff = arr_avg - a
        sqr = diff * diff
        sqrs.append(sqr)
    # Average of squares of diffs
    sqrs_avg = average(sqrs)
    # Square root
    res = math.sqrt(sqrs_avg)
    return res


def populate(
    crate,
    labels_file,
    data_file,
    data_file_loc,
    numnodes,
    numruns):
    # Use same headers and will be using similar logic as "aggregate_bench.py" later on
    headers = ['#','bench-name','unmod-time', 'unmod-error','nobc-time','nobc-error','nobc+sl-time','nobc+sl-error','safelib-time','safelib-error']
    
    # Read in labels to eventually put in output file
    fd_labels = open(labels_file, 'r')
    labels = []
    for line in fd_labels:
        labels.append(line.rstrip())
#    print(labels)

    # Grab the numbers for each [benchmark x rustc] combo (per crate)
    base_file = "./crates/crates/" + crate + "/" + data_file_loc + "/" + data_file
    crunched_output = base_file + "-CRUNCHED.data"
    # Write headers
    path_wrangle(crunched_output, headers)

    # Each loop here represents a different .data file, meaning that
    # each loop iteration adds to all the arrays _once_ (one data point
    # per file); so the arrays we write to should be created outside of this
    # main processing loop

    totalruns = int(numnodes) * int(numruns)
    rows = len(labels)
    cols = 4
    matrix = numpy.zeros((rows,cols,totalruns))
    print(matrix)
    
    for i in range(int(numnodes)):
        for j in range(1, int(numruns) + 1):
            fd_data_file = base_file + "-" + str(i) + "-" + str(j) + ".data"
            fd_data = open(fd_data_file, 'r')

            row = 0
            for line in fd_data:
                # Skip header line
                if line[:1] == '#':
                    continue
                # Each line = results of one benchmark name/function runs with four different rustc
                columns = line.split()
                col = 0
                for c in range(len(columns)):
                    if c % 2 == 1:
                        elem = columns[c]
                        print("ADDING " + elem + " at ROW=" + str(row) + " and COL=" + str(col))
                        old = matrix[0][row][col]
                        new = old.append(int(elem))
                        matrix[0][row][col] = new
                        col += 1
                row += 1
                print(matrix)
                print("\n\n")


def path_wrangle(filepath, headers):
    """ Check for or create path and output file
    There's no error handling, because noisy failure's probably a good thing
    """
    # check for or create directory path
    directory = os.path.split(filepath)[0]
    if not os.path.exists(directory):
            os.makedirs(directory)
    # regardless if file itself exists or not, want blank slate so:
    # create new or overwrite existing data
    with open(filepath, 'w') as newhandle:
        writerow(newhandle, headers)


def writerow(filehandle, array):
    """ Write the contents of the array as a white-space
    delimited row in the file
    """
    for elem in array:
        filehandle.write(elem)
        filehandle.write("\t")
    filehandle.write("\n")


# Called like: python3 "$CRUNCH" "$crate" "$BENCH_LABELS" "$FNAME" "$LOCAL_OUTPUT" "$numnodes" "$runs"
if __name__ == "__main__":
    if len(sys.argv) != 7: 
        sys.exit("Wrong number of arguments! Need 7.")
    crate = sys.argv[1]
    bench_label_file = sys.argv[2]
    data_file_name = sys.argv[3]
    data_file_loc = sys.argv[4]
    numnodes = sys.argv[5]
    numruns = sys.argv[6]

    # Populate Arrays
    populate(
        crate=crate,
        labels_file=bench_label_file,
        data_file=data_file_name,
        data_file_loc=data_file_loc,
        numnodes=numnodes,
        numruns=numruns
    )
