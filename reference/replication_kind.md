# Classify a registry study by materials layout

Classify a registry study by materials layout

## Usage

``` r
replication_kind(meta, ctx = NULL)
```

## Arguments

- meta:

  Parsed replication metadata (registry stub or full yaml).

- ctx:

  Optional paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

`"package"`, `"folder"`, or `"registry"`.
