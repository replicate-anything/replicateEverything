# Merge full study package steps into a lightweight registry stub

Registry stubs omit the DAG. When the stub points at a package-backed
study, load `steps:` from the study package yaml (local install or
configured path).

## Usage

``` r
enrich_package_replication_meta(meta, ctx)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

Updated metadata list.
