# Load a precomputed artifact for a replication

Load a precomputed artifact for a replication

## Usage

``` r
load_artifact(doi, what, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., `"fig_1"`).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Artifact contents suitable for display, or `NULL`.
