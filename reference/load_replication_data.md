# Load replication data files

Supports CSV, RDS, and Stata DTA files from a local registry checkout or
remote raw GitHub URLs.

## Usage

``` r
load_replication_data(data_files, ctx)
```

## Arguments

- data_files:

  Character vector of paths relative to the paper folder.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

A data frame, a named list of objects, or `NULL`.
