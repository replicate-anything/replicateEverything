# Replicate all results from a paper

Runs all registered replications (figures and tables) for a given paper.

## Usage

``` r
replicate_paper(doi, install_deps = FALSE)
```

## Arguments

- doi:

  Character. DOI of the paper.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

## Value

A named list of replication result envelopes.
