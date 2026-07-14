# Validate that a single precomputed output exists

Validate that a single precomputed output exists

## Usage

``` r
validate_single_output(doi, what, repo = NULL, folder = NULL, language = NULL)
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

Invisibly `TRUE` on success.
