# Run a single replication

Executes a specific replication (figure or table) for a paper.

## Usage

``` r
run_replication(doi, what)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., "fig_1").

## Value

A plot or table produced by the replication code.

## Examples

``` r
if (FALSE) { # \dontrun{
run_replication("10.1177/00491241211036161", "fig_1")
} # }
```
