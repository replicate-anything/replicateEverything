# Folder names to check when locating a sibling folder-backed study repo

Folder names to check when locating a sibling folder-backed study repo

## Usage

``` r
study_folder_candidates(meta, ctx = NULL)
```

## Arguments

- meta:

  Parsed replication.yml contents.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

Character vector of folder names (no duplicates).
