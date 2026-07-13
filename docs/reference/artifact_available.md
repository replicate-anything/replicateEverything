# Check whether a precomputed artifact is available

Check whether a precomputed artifact is available

## Usage

``` r
artifact_available(doi, what, repo = NULL, folder = NULL, language = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (logical id, e.g. `"tab_1"`).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

- language:

  Optional `"R"` or `"stata"`.

## Value

Logical scalar.

## Examples

``` r
if (FALSE) { # \dontrun{
artifact_available("10.1177/00491241211036161", "fig_1")
} # }
```
