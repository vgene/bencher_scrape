# Scraping Benchmarks on cargo.io

We use the [reverse dependencies](https://crates.io/crates/bencher/reverse_dependencies) of the [bencher](https://crates.io/crates/bencher) crate to get a list of crates with benchmarks that we can use.

We scrape this reverse-dependency list to get a set of crates that we can download and install locally. To run the crawling/scraping tool run: 

`scrapy crawl crates`

in the `crates/` subdirectory. 
