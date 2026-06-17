# Get artifact URL or local path for a replication

Get artifact URL or local path for a replication

## Usage

``` r
get_artifact_path(doi, what, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Replication identifier.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Character path or URL, or `NULL` if no artifact is registered.
