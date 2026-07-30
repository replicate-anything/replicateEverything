# Resolve all declared displayable artifact paths for a replication

Unlike
[`get_artifact_path()`](https://replicate-anything.github.io/replicateEverything/reference/get_artifact_path.md),
which returns the first existing candidate, this returns every declared
`outputs:` display sink that exists on disk (or a single fallback path
when none of the declared sinks exist). Used by Shiny Display to stack
multi-panel figures.

## Usage

``` r
get_artifact_paths(doi, what, repo = NULL, folder = NULL, language = NULL)
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

Character vector of local paths or URLs (may be length 0).
