# Resolve display output for an already-selected result

Resolve display output for an already-selected result

## Usage

``` r
resolve_replication_display(
  doi,
  what,
  result,
  source = c("artifact", "live"),
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Replication identifier.

- result:

  Artifact HTML/path, replication result list, or analysis object.

- source:

  Character. `"artifact"` or `"live"`.

- install_deps:

  Logical. Passed to
  [`format_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/format_for_display.md).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name.

## Value

A list with `ok`, `value`, and optional `error` or `missing`.
