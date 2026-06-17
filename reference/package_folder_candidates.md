# Folder names to check when locating a sibling replication package

Folder names to check when locating a sibling replication package

## Usage

``` r
package_folder_candidates(package, meta, ctx)
```

## Arguments

- package:

  R package name.

- meta:

  Parsed replication.yml contents.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

Character vector of folder names (no duplicates).
