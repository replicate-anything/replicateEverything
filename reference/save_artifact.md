# Save a replication result as an artifact file

Save a replication result as an artifact file

## Usage

``` r
save_artifact(
  result,
  output_dir,
  doi = NULL,
  repo = NULL,
  folder = NULL,
  install_deps = FALSE
)
```

## Arguments

- result:

  A replication result envelope from
  [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md).

- output_dir:

  Directory in which to write the artifact.

- doi:

  Optional DOI; required to apply a registered `format_*` step.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name.

- install_deps:

  Logical; passed to
  [`format_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/format_for_display.md).

## Value

Invisibly the output file path.
