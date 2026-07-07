# Run Stata SSC / dependency install scripts for a study

Run Stata SSC / dependency install scripts for a study

## Usage

``` r
install_stata_dependencies(
  study_root,
  staging_dir = NULL,
  meta = NULL,
  rep = NULL,
  install_deps = FALSE
)
```

## Arguments

- meta:

  Optional parsed replication metadata for study resolution.

- rep:

  Replication entry.

- install_deps:

  When `FALSE`, returns immediately.
