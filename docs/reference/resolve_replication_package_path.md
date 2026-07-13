# Resolve a local path to a study replication package

Search order:

1.  Explicit path in `paper.package_path` (if it exists)

2.  `getOption("replicateEverything.replication_packages")` map

3.  Sibling folders under `replication_packages_root` or monorepo root

## Usage

``` r
resolve_replication_package_path(package, meta, ctx)
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

Normalized path, or `NULL`.
