# Validate that a replication can be rendered

Validate that a replication can be rendered

## Usage

``` r
validate_replication(doi, what, language = NULL, install_deps = FALSE)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Replication identifier.

- install_deps:

  Logical. Passed to
  [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md).

## Value

Invisibly `TRUE` on success.

## Examples

``` r
if (FALSE) { # \dontrun{
validate_replication("10.1177/00491241211036161", "fig_1")
} # }
```
