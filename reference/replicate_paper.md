# Replicate all results from a paper

Runs one replication per logical figure/table group, using the default
engine (R when both R and Stata exist).

## Usage

``` r
replicate_paper(doi, language = NULL, install_deps = FALSE)
```

## Arguments

- doi:

  Character. DOI of the paper.

- language:

  Optional `"R"` or `"stata"` for all groups.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

## Value

A named list of replication result envelopes.

## Examples

``` r
if (FALSE) { # \dontrun{
replicate_paper("10.1177/00491241211036161")
} # }
```
