# Prepare a folder-backed study for registry sync

Runs
[`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md),
[`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md),
and on success writes `registry/replication.yml` and
`registry/index.csv` in the study repository. The only registry step
left is syncing those files (see
[`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md)).

## Usage

``` r
prepare_folder_paper(
  location = ".",
  build_artifacts = TRUE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL
)
```

## Arguments

- location:

  Study repo path. Defaults to `"."`.

- build_artifacts:

  If `TRUE`, run
  [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md)
  first.

- install_deps:

  Passed to
  [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md).

- full_replication:

  Passed to
  [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md).

- registry_root:

  Optional registry checkout for monorepo dev.

## Value

Invisibly, the result of
[`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md)
with `registry_stub_path` and `registry_index_path` when successful.
