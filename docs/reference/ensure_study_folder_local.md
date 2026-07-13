# Ensure a folder-backed study is available on local disk

Search order: explicit paths and sibling folders, optional
`replicateEverything.study_folders` map, then GitHub archive cache.

## Usage

``` r
ensure_study_folder_local(meta, ctx = NULL)
```

## Arguments

- meta:

  Parsed registry or study metadata.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

Normalized study root, or `NULL`.
