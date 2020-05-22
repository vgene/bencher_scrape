#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
A wrapper for cargo bench
Its numeric output is parsed and dumped to a csv
Pass an an optional independent variable from the command line
And also any other static keys and values

USAGE: python aggregate_bench.py [independent variable]
Writes to measurements.csv in the cwd by default, pass a different filepath to alter this
any other keyword arguments will be written as a header row and value. Be careful with that.

(C) Stephan Hügel 2016
License: MIT

Original: https://github.com/urschrei/lonlat_bng/blob/master/aggregate_bench.py
Adapted by: Natalie Popescu 2020
"""
import os
import sys
from subprocess import check_output
import re

pattern = "bench:\s+([0-9,]*)\D+([0-9,]*)"

def dump_benchmark(
    pattern,
    filepath="./bench.data",
    headers=['#','unmod-time', 'unmod-error','mod-time','mod-error'],
    idep_var=None,
    **kwargs):
    """ If I have to append benchmark output to a CSV once more I'm going
    to drown the world in a bath of fire. This should just work.
    Customise with your own output path and header row.
    idep_var is an optional independent variable.
    """
    # run cargo bench in cwd, capture output
    unmod_result = re.findall(pattern, check_output(["cat", "unmod.bench"]).decode('utf-8'))
    mod_result = re.findall(pattern, check_output(["cat", "mod.bench"]).decode('utf-8'))
    # get rid of nasty commas
    output = []
    unmod_len = len(unmod_result)
    mod_len = len(mod_result)
    length = unmod_len if unmod_len < mod_len else mod_len
    for i in range(length):
        line = []
        # grab each matched line
        unmod_line = unmod_result[i]
        mod_line = mod_result[i]
        # grab each of the two numbers per line
        for num in unmod_line:
            tnum = num.translate({ord(','): None})
            line.append(tnum)
        for num in mod_line:
            tnum = num.translate({ord(','): None})
            line.append(tnum)
        output.append(line)
    # any other kwargs will be written as a CSV header row and value
    # nothing prevents you from writing rows that don't have a header
    for k, v in kwargs.items():
        headers.append(k),
        output.append(v)
    # check that path and file exist, or create them
    path_wrangle(filepath, headers)
    # write data to the file
    with open(filepath, 'a') as handle:
        for elem in output:
            writerow(handle, elem)

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

if __name__ == "__main__":
    # You know what an independent variable is, of course
    idep_var = None
    # So brittle. Shhh.
    if len(sys.argv) > 1 and sys.argv[1] is not None:
        idep_var = sys.argv[1]
    dump_benchmark(
        pattern,
        filepath="./bench.data",
        idep_var=idep_var,
    )
