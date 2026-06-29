# Run a single replication

Executes a specific replication (figure or table) for a paper.

## Usage

``` r
run_replication(doi, what, install_deps = FALSE)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., "fig_1").

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

## Value

The underlying replication object.

## Examples

``` r
if (FALSE) { # \dontrun{
run_replication("10.1177/00491241211036161", "fig_1")
} # }
```
