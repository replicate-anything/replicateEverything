# Display artifact directory for a study

Folder-backed studies use `artifacts/`; package-backed studies use
`inst/report/artifacts/` in the source tree or installed package.

## Usage

``` r
study_artifact_dir(meta, ctx = NULL, installed = TRUE, package = NULL)
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

Normalized directory path or `NULL`.
