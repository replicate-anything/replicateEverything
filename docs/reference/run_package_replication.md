# Run a package-backed replication via study make\_*/format\_* (or legacy wrapper)

Prefers a legacy study-package
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
only when present. New study packages should not ship that verb — this
function calls exported `make_*` / `format_*` (and prep helpers) from
the package namespace.

## Usage

``` r
run_package_replication(package, id, meta = NULL, install_deps = FALSE)
```

## Arguments

- package:

  Study package name.

- id:

  Replication id from yaml.

- meta:

  Optional parsed package yaml (defaults to installed yaml).

- install_deps:

  Ignored for native runs; passed to legacy wrappers.

## Value

Analysis or display object (format\_\* applied when declared).
