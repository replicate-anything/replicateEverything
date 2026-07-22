# Build get_code output for a package-backed study from remote source

Build get_code output for a package-backed study from remote source

## Usage

``` r
get_code_from_package_repo(
  meta,
  ctx,
  what,
  package,
  mode = c("definitions", "run")
)
```

## Arguments

- meta:

  Parsed replication metadata (with replications list).

- ctx:

  Paper context.

- what:

  Replication id.

- package:

  R package name.
