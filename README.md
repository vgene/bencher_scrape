# Scraping Benchmarks on cargo.io

We use the [reverse dependencies](https://crates.io/crates/bencher/reverse_dependencies) of the [bencher](https://crates.io/crates/bencher) crate to get a list of crates with benchmarks that we can use.

We use the python tool, [scrapy](https://docs.scrapy.org/en/latest/index.html#), to scrape this reverse-dependency list. This will give us a list of crates that use the bencher crate to run their benchmarks, and will pull those crates from cargo.io.

## Run the Tool:

Set up your python and [scrapy](https://docs.scrapy.org/en/latest/intro/install.html) environments. Then run:

`scrapy crawl crates`

in the `crates/` subdirectory. Upon completion, this command should automatically:

1. Download and install the crate code
2. Run the benchmarks normally
3. Run the benchmarks with Rust bounds checks turned off
