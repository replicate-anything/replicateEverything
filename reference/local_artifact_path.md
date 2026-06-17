# Get the local artifact file path for a replication, if available

Get the local artifact file path for a replication, if available

## Usage

``` r
local_artifact_path(doi, what, repo = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., `"fig_1"`).

- repo:

  Optional repository slug.

## Value

Character path or `NULL`.
