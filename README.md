# Scraping Benchmarks on cargo.io

We use the [reverse dependencies](https://crates.io/crates/bencher/reverse_dependencies) of the [bencher](https://crates.io/crates/bencher) crate to get a list of crates with benchmarks that we can use.

Using the python tool, [scrapy](https://docs.scrapy.org/en/latest/index.html#), we scrape this reverse-dependency list to get a list of crates that use the bencher crate to run benchmarks, and leverage those benchmarks to evaluate the performance impact of Rust bounds checks.

## Running the Tool

After setting up your python and [scrapy](https://docs.scrapy.org/en/latest/intro/install.html) environments, simply run:

`./bench.sh`

## End Goals

Upon completion, this command should automatically:

1. Download and install the crate code [done]
2. Run the benchmarks normally [done]
3. Run the benchmarks with Rust bounds checks turned off
4. Generate a compact form of comparison between the two sets of benchmarks
