#!/usr/bin/env python

import os
import sys
import math
from subprocess import check_output
import numpy
import re

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


def crunch(
    crate,
    data_file,
    data_file_loc,
    numnodes,
    numruns):
    # Use same headers and will be using similar logic as "aggregate_bench.py" later on
    headers = ['#','bench-name','unmod-time', 'unmod-error','nobc-time','nobc-error','nobc+sl-time','nobc+sl-error','safelib-time','safelib-error']
    
    # Grab the numbers for each [benchmark x rustc] combo (per crate)
    base_file = "./crates/crates/" + crate + "/" + data_file_loc + "/" + data_file
    crunched_output = base_file + "-CRUNCHED.data"
    # Write headers
    path_wrangle(crunched_output, headers)

    # Each loop here represents a different .data file, meaning that
    # each loop iteration adds to all the arrays _once_ (one data point
    # per file); so the arrays we write to should be created outside of this
    # main processing loop
    get_names_file = base_file + "-0-1.data"

    totalruns = int(numnodes) * int(numruns)
    rows = len(open(get_names_file, 'r').readlines()) - 1
    cols = 4
    matrix = numpy.zeros((rows, cols, totalruns))

    get_names = True
    # Flag needed because bug in my regex for extracting benchmark names =>
    # creates an offset when process the numbers, leading program to try to parse
    # the actual benchmark name as a float (this bug only manifests sometimes, 
    # when there is only a single benchmark, don't know why)
    extra_name = False
    labels = []
    run = 0
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
                    if get_names == True and c == 0:
                        if columns[c] == "test":
                            extra_name = True
                            continue
                        else: 
                            labels.append(columns[c])
                    if extra_name == True and c == 1:
                        labels.append(columns[c])
                    # Collect numbers @ even columns (skipping first) if extra name column exists
                    if extra_name == True and c > 0 and c % 2 == 0:
                        elem = columns[c]
                        matrix[row][col][run] = elem
                        col += 1
                    # Otherwise collect numbers @ odd columns
                    elif extra_name == False and c % 2 == 1:
                        elem = columns[c]
                        matrix[row][col][run] = elem
                        col += 1
                row += 1
            get_names = False
            run += 1

    fd_crunched_output = open(crunched_output, 'a')
    # Now that we've populated our matrix, can start crunching numbers
    for r in range(rows):
        row = []
        label = labels[r]
        row.append(label)
        for c in range(cols):
            # Order when print matrix: 
            #   unmod
            #   nobc
            #   nobc+sl
            #   safelib
            avg = average(matrix[r][c])
            stdev = stddev(matrix[r][c], avg)
            row.append(str(avg))
            row.append(str(stdev))
        writerow(fd_crunched_output, row)

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


# Called like: python3 "$CRUNCH" "$crate" "$FNAME" "$LOCAL_OUTPUT" "$numnodes" "$runs"
if __name__ == "__main__":
    if len(sys.argv) != 6: 
        sys.exit("Wrong number of arguments! Need 6.")
    crate = sys.argv[1]
    data_file_name = sys.argv[2]
    data_file_loc = sys.argv[3]
    numnodes = sys.argv[4]
    numruns = sys.argv[5]

    # Get average and stddev across all nodes + runs
    crunch(
        crate=crate,
        data_file=data_file_name,
        data_file_loc=data_file_loc,
        numnodes=numnodes,
        numruns=numruns
    )
