# Whether a study replication package namespace can be used

Modern study packages export `make_*` / `format_*` only (verbs live in
replicateEverything). Legacy packages may still ship
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md).
Either shape counts as usable when the package loads and exposes
replication metadata or analysis helpers.

## Usage

``` r
replication_package_usable(package)
```

## Arguments

- package:

  Installed or dev-loaded package name.
