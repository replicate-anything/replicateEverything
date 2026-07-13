# Run Stata SSC / dependency install scripts for a study (maintainer builds only)

Run Stata SSC / dependency install scripts for a study (maintainer
builds only)

## Usage

``` r
install_stata_dependencies(
  study_root,
  staging_dir = NULL,
  meta = NULL,
  rep = NULL,
  install_deps = FALSE,
  force = FALSE
)
```

## Arguments

- meta:

  Optional parsed replication metadata for study resolution.

- rep:

  Replication entry.

- install_deps:

  When `FALSE`, returns immediately.
