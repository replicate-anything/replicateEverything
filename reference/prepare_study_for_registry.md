# Prepare a study repository for registry handoff (contributor)

Validates a folder- or package-backed study, then writes the short
registry yaml and one-row `index.csv` into the study repository:

## Usage

``` r
prepare_study_for_registry(
  location = ".",
  build_artifacts = TRUE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL
)

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

  Study repo path or GitHub address. Defaults to `"."`.

- build_artifacts:

  If `TRUE`, build precomputed outputs first.

- install_deps:

  Passed to the build function.

- full_replication:

  If `TRUE`, also run every table and figure live.

- registry_root:

  Optional registry checkout (passed to build/check helpers).

## Value

Invisibly, a checklist result with `registry_stub_path` and
`registry_index_path` when successful.

## Details

- Folder studies: `registry/replication.yml` and `registry/index.csv`

- Package studies: `inst/registry/replication.yml` and
  `inst/registry/index.csv`

This is the **contributor** step. A registry maintainer installs those
files with
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
and refreshes the central index with
[`refresh_registry()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry.md).

Runs
[`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md)
or
[`build_package_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_package_artifacts.md)
(optional), then
[`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md)
or
[`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md),
and on success writes and validates the registry stub via
[`write_study_registry_stub()`](https://replicate-anything.github.io/replicateEverything/reference/write_study_registry_stub.md).

## Functions

- `prepare_folder_paper()`: Deprecated alias for folder studies.

## Examples

``` r
if (FALSE) { # \dontrun{
prepare_study_for_registry(".")
} # }
```
