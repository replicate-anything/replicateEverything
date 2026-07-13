# Load replication data files

Supports CSV, RDS, and Stata DTA files from a local registry checkout or
remote raw GitHub URLs.

## Usage

``` r
load_replication_data(data_files, ctx, meta = NULL)
```

## Arguments

- data_files:

  Character vector of paths relative to the paper folder.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

- meta:

  Optional parsed replication metadata for external data lookup.

## Value

A data frame, a named list of objects, or `NULL`.
