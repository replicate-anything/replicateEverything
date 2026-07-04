# Get the local artifact file path for a replication, if available

Get the local artifact file path for a replication, if available

## Usage

``` r
local_artifact_path(doi, what, repo = NULL, language = NULL)
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

Character path or `NULL`.
