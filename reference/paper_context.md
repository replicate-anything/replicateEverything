# Build base URLs and paths for a paper in the registry

Build base URLs and paths for a paper in the registry

## Usage

``` r
paper_context(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug. Defaults to `find_repo(doi)`.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A list with `repo`, `folder`, `base_url`, and optional `local_root`.
