# Load or run a replication for display

Centralizes artifact-vs-live logic for Shiny and other front ends.

## Usage

``` r
load_replication_for_display(
  doi,
  what,
  prefer = c("auto", "artifact", "live"),
  fallback_live = TRUE,
  install_deps = TRUE,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Replication identifier.

- prefer:

  Character. `"artifact"` tries the precomputed file first; `"live"`
  runs the replication; `"auto"` is an alias for `"artifact"` with
  `fallback_live = TRUE`.

- fallback_live:

  When `TRUE` and the artifact is missing, run live.

- install_deps:

  Logical. Passed to live rendering.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name.

## Value

A list with `ok`, `value`, `source` (`"artifact"` or `"live"`), and
optional `error` or `missing`.
