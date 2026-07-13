# Display output directory for a study (legacy name: `study_artifact_dir()`)

Folder-backed studies use `outputs/`. Package-backed studies use
`inst/report/outputs/`.

## Usage

``` r
study_output_dir(meta, ctx = NULL, installed = TRUE, package = NULL)

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
