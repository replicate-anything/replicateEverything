# Build table and figure artifacts into a directory

Build table and figure artifacts into a directory

## Usage

``` r
build_display_artifact_entries(
  display_reps,
  doi,
  artifact_dir,
  folder = NULL,
  install_deps = FALSE,
  study_root = NULL
)
```

## Arguments

- display_reps:

  List of replication entries.

- doi:

  Paper DOI.

- artifact_dir:

  Output directory.

- folder:

  Optional registry folder name.

- install_deps:

  Passed to runners.

- study_root:

  Optional root for portable error messages.
