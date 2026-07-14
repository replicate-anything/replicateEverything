# Resolve a registry index row to a study location for maintainer APIs

Rows without a DOI (handle-only stubs) must not pass an empty string to
[`install_study_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_study_dependencies.md),
because blank input means "local study in getwd()".

## Usage

``` r
resolve_index_study_location(row)
```

## Arguments

- row:

  One row from
  [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md).

## Value

Character DOI, handle, or folder slug.
