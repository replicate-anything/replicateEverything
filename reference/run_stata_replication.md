# Run a Stata-backed replication entry

Run a Stata-backed replication entry

## Usage

``` r
run_stata_replication(rep, ctx, meta = NULL, install_deps = FALSE)
```

## Arguments

- rep:

  Replication entry.

- ctx:

  Paper context.

- meta:

  Optional parsed replication metadata for study resolution.

- install_deps:

  When `TRUE`, run study Stata dependency install scripts before the
  replication and retry once after package-missing failures.

## Value

A `stata_replication_result` list.
