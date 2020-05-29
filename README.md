# Scraping Benchmarks on cargo.io

We use the [reverse dependencies](https://crates.io/crates/bencher/reverse_dependencies) of the [bencher](https://crates.io/crates/bencher) crate to get a list of crates with benchmarks that we can use.

Using the python tool, [scrapy](https://docs.scrapy.org/en/latest/index.html#), we scrape this reverse-dependency list to get a list of crates that use the bencher crate to run benchmarks, and leverage those benchmarks to evaluate the performance impact of Rust bounds checks.

## Running the Tool

After setting up your python and [scrapy](https://docs.scrapy.org/en/latest/intro/install.html) environments,
you can just run the tool with the default configuration by simply running: 

`./bench.sh`

The default configuration does the following: 

- [ ] Scrapes crates.io and downloads crates
- [X] Benchmarks crates after compiling with _both_ (unmodified and modified) rustc versions
- [ ] Runs crate tests using the version compiled with modified rust
- [X] Diffs benchmark output and copies data-aggregation and plotting scripts into the crate directory

In the following subdirectories under [crates](https://github.com/nataliepopescu/bencher_scrape/tree/master/crates): 

- [ ] better
- [X] inconsistent
- [ ] worse

Run: 

`./bench.sh -h`

To see the flags you can use to further tailor the script's functionality. 

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
[these](http://www.gnuplot.info/download.html). I am using version 5.2 (installed with homebrew), and the 
default terminal type is 'qt'.

2. `cp gnuplot-script ./path/to/data/file/directory`. For example, one data file is 
[this](https://github.com/nataliepopescu/bencher_scrape/blob/master/crates/clones/KDFs/bench-sanity.data)
one, so the path to the directory would be: `crates/clones/KDFs/`

3. Navigate into the directory from the above step

4. Start up gnuplot by simply typing: `gnuplot`

5. In gnuplot's REPL, type: `filename="bench-sanity.data"; load "gnuplot-script"`

## What Changes are we Measuring?

See them [here](https://github.com/nataliepopescu/rust).

### Building the Modified Rustc Locally

Clone the [repo](https://github.com/nataliepopescu/rust) and largely follow the instructions listed there.
This includes double checking all of your dependencies. You may also want to change the default "prefix" 
directory (installation location of this rustc) to something you have write access to. Normally, running
`which rustc` lands me in `~/.cargo/bin/rustc`, so I just created an analogous directory `~/.cargo-mod/` 
and changed my config.toml respectively:

```
[install]

...

prefix = "/Users/np/.cargo-mod"
```

When you are ready to build and install, run:

```sh
$ ./x.py build && ./x.py install && ./x.py install cargo
```

Note that this will take a while. Once the modified rustc is installed and you are ready to build with it,
you should set the `CARGO_BUILD_RUSTC` environment variable to point to the modified rustc, i.e.:

```sh
$ export $CARGO_BUILD_RUSTC="/Users/np/.cargo-mod/bin/rustc"
```

The `bench.sh` script toggles this environment variable back and forth between `~/.cargo/bin/rustc` and
`~/.cargo-mod/bin/rustc`, which you can do manually as well. 

## End Goals

Upon completion, this command should automatically:

1. Download and install the crate code [done]
2. Run the benchmarks normally [done]
3. Run the benchmarks with Rust bounds checks turned off [in progress]
4. Generate a compact form of comparison between the two sets of benchmarks [done-ish]
