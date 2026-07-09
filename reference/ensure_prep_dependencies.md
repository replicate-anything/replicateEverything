# Ensure prep dependencies exist before running a replication

Ensure prep dependencies exist before running a replication

## Usage

``` r
ensure_prep_dependencies(
  meta,
  rep,
  ctx,
  doi,
  install_deps = FALSE,
  force = FALSE
)
```

## Arguments

- meta:

  Parsed metadata.

- rep:

  Replication entry.

- ctx:

  Paper context.

- install_deps:

  Passed to prep runners.

- force:

  Re-run prep even when outputs exist.
