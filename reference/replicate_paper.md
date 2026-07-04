# Replicate all results from a paper

**Deprecated.** Use
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
with `what = "everything"` instead.

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

A named list of replication result envelopes (legacy behaviour).

## Examples

``` r
if (FALSE) { # \dontrun{
replicate_paper("10.1177/00491241211036161")
run_replication("10.1177/00491241211036161", "everything")
} # }
```
