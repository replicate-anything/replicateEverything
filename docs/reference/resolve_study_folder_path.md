# Resolve a local path to a folder-backed study repository

Search order mirrors package sibling resolution: explicit
`paper.study_path`, option map, then sibling monorepo folders.

## Usage

``` r
resolve_study_folder_path(meta, ctx = NULL)
```

## Arguments

- meta:

  Parsed replication.yml contents.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

Normalized path, or `NULL`.
