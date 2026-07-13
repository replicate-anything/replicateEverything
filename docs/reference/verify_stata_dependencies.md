# Verify Stata dependencies via study yaml probe (no install)

Verify Stata dependencies via study yaml probe (no install)

## Usage

``` r
verify_stata_dependencies(
  study_root,
  staging_dir = NULL,
  meta = NULL,
  rep = NULL
)
```

## Arguments

- meta:

  Optional parsed replication metadata for study resolution.

- rep:

  Replication entry.

## Value

Invisibly `TRUE` when satisfied.
