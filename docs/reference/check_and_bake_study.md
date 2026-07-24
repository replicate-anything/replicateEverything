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

  Study repo path or GitHub address. Defaults to `"."` — the current
  working directory, i.e. the same study `doi = "local"` resolves to for
  [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
  /
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  /
  [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md).

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
# setwd() to the study repo (or open its RStudio project) first.
setwd("path/to/rep-my-study")

# Manual smoke check before the full contributor checklist — no
# registry required:
list_replications("local")
describe_study_dag("local")
run_replication("local", "tab_1")  # one light step

check_and_bake_study(".")
} # }
```
