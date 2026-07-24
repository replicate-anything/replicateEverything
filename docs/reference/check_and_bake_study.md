# Build outputs and validate a study (contributor)

Optionally bakes display artifacts with
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md),
then runs
[`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md).
On success the study is ready for a maintainer to register it with
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
(stub written only into the central registry repository).

## Usage

``` r
check_and_bake_study(
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

Invisibly, a checklist result (`folder_replication_check` or
`package_replication_check`).

## Examples

``` r
if (FALSE) { # \dontrun{
check_and_bake_study(".")
} # }
```
