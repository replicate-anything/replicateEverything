# Run a replication and return a result or error object

Like
[`render_for_display`](https://replicate-anything.github.io/replicateEverything/reference/render_for_display.md)
but never throws; failures are returned as `simpleError` objects.

## Usage

``` r
try_render_for_display(doi, what, install_deps = FALSE, repo = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., `"fig_1"`).

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

- repo:

  Optional repository slug.

## Value

A replication result list, a display-ready object, or an error.

## Examples

``` r
if (FALSE) { # \dontrun{
try_render_for_display("10.1177/00491241211036161", "fig_1")
} # }
```
