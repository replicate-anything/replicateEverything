# Validate that a precomputed artifact exists

Validate that a precomputed artifact exists

## Usage

``` r
validate_artifact(doi, what, repo = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., `"fig_1"`).

- repo:

  Optional repository slug.

## Value

Invisibly `TRUE` on success.

## Examples

``` r
if (FALSE) { # \dontrun{
validate_artifact("10.1177/00491241211036161", "fig_1")
} # }
```
