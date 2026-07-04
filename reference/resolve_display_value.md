# Resolve a replication result envelope to a display-ready value

Accepts a precomputed artifact, a
[`render_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/render_for_display.md)
result, or a raw analysis object. Applies
[`format_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/format_for_display.md)
when needed.

## Usage

``` r
resolve_display_value(
  doi,
  what,
  result,
  language = NULL,
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

- install_deps:

  Logical. Passed to
  [`format_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/format_for_display.md).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name.

## Value

Display-ready value (HTML string, ggplot, path, etc.) or an error.
