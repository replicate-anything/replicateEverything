# Add a folder-backed study to the replication registry

Validates a folder-backed study with
[`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md),
writes or reuses `registry/replication.yml` and `registry/index.csv` in
the study repo, then copies them into the registry checkout via
[`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md).

## Usage

``` r
add_folder_paper(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  build_artifacts = FALSE,
  install_deps = TRUE
)
```

## Arguments

- location:

  Local study path or GitHub address. Defaults to `"."`.

- full_replication:

  If `TRUE`, also run every table and figure live.

- registry_root:

  Path to the registry repository root. Defaults to
  `getOption("replicateEverything.registry_root")`.

- dry_run:

  If `TRUE`, run checks only; do not write registry files.

- build_artifacts:

  If `TRUE`, run
  [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md)
  before checks.

- install_deps:

  Passed to
  [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md).

## Value

Invisibly, the result of
[`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md),
with `stub_path` and `index_updated` when registration succeeds.

## Details

Equivalent to
[`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md)
followed by
[`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md)
when you already have a local registry checkout. If you only need the
stub files, use
[`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md)
and copy them manually.
