# Manifest path for a study's precomputed display artifacts

Manifest path for a study's precomputed display artifacts

## Usage

``` r
study_manifest_path(meta, ctx = NULL, installed = TRUE, package = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

- installed:

  When `TRUE`, prefer the installed package path.

- package:

  Optional package name (package-backed studies).

## Value

Character path or `NULL`.
