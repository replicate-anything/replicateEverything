# Validate that a precomputed artifact exists

Validate that a precomputed artifact exists

## Usage

``` r
validate_artifact(doi, what, repo = NULL, language = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (logical id, e.g. `"tab_1"`).

- repo:

  Optional repository slug.

- language:

  Optional `"R"` or `"stata"`.

## Value

Invisibly `TRUE` on success.

## Examples

``` r
if (FALSE) { # \dontrun{
validate_artifact("10.1177/00491241211036161", "fig_1")
} # }
```
