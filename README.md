# Scraping Benchmarks on cargo.io

We use the [reverse dependencies](https://crates.io/crates/bencher/reverse_dependencies) of the [bencher](https://crates.io/crates/bencher) crate to get a list of crates with benchmarks that we can use.

Using the python tool, [scrapy](https://docs.scrapy.org/en/latest/index.html#), we scrape this reverse-dependency list to get a list of crates that use the bencher crate to run benchmarks, and leverage those benchmarks to evaluate the performance impact of Rust bounds checks.

## Running the Tool

After setting up your python and [scrapy](https://docs.scrapy.org/en/latest/intro/install.html) environments, simply run:

`./bench.sh`

Note that this script generates and aggregates the data as:

 1) [*.diff] files whose contents are the output of `diff`ing the 
two sets of benchmarks, and

 2) [*.data] files that contain the parsed output of these benchmarks and which
can be easily used to generate a graph with gnuplot.

The `diff` output is meant for manual inspection
of specific benchmark numbers, whereas the parsed data file/the plot 
generated from it is more useful in conveying the 
overall performance characteristic(s) of the crate.

## Generating Graphs

The `gnuplot-script` reads from the respective `bench-sanity.data` files, so (in the current state of the tool)
the script should be invoked from the same directory as the data you want to visualize. 

Therefore: 

1. Install [gnuplot](http://www.gnuplot.info/) either by way of your system package manager or by following one of 
[these](http://www.gnuplot.info/download.html). I am using version 5.2, and default terminal type is 'qt'.

2. `cp gnuplot-script ./path/to/data/file/directory` 

        one data file is 
        [this one](https://github.com/nataliepopescu/bencher_scrape/blob/master/crates/clones/KDFs/bench-sanity.data), 
        so the path to the directory would be: `crates/clones/KDFs/`

3. Navigate into the directory from the above step

4. Start up gnuplot by simply typing: `gnuplot`

5. In gnuplot's REPL, type: `load "gnuplot-script"`

## What Changes are we Measuring?

See them [here](https://github.com/nataliepopescu/rust).

## End Goals

Upon completion, this command should automatically:

1. Download and install the crate code [done]
2. Run the benchmarks normally [done]
3. Run the benchmarks with Rust bounds checks turned off [in progress]
4. Generate a compact form of comparison between the two sets of benchmarks [done-ish]
