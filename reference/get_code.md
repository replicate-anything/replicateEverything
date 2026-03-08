# Retrieve replication code for a paper

Downloads and returns the replication script associated with a specific
figure or table from the replication registry.

## Usage

``` r
get_code(doi, what)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., `"fig_1"`).

## Value

A character vector containing the lines of R code from the replication
script.

## Details

The function locates the appropriate replication repository using
[`find_repo()`](https://replicate-anything.github.io/replicateEverything/reference/find_repo.md),
constructs the URL to the replication script, and downloads the script
from the registry.

## Examples

``` r
if (FALSE) { # \dontrun{
get_code("10.1177/00491241211036161", "fig_1")
} # }
```
