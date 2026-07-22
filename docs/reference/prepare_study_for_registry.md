# Validate a study repository before registry onboarding (contributor)

Builds outputs (optional) and runs
[`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md).
On success, the study is ready for a maintainer to register it with
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md),
which writes the stub **only** into the central registry repository (not
into the study repo).

## Usage

``` r
prepare_study_for_registry(
  location = ".",
  build_artifacts = TRUE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL,
  write_handoff = FALSE
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

- write_handoff:

  If `TRUE`, also write a legacy study-local stub under `registry/` or
  `inst/registry/` (not recommended; stubs belong in the registry repo).
  Default `FALSE`.

## Value

Invisibly, a checklist result; when `write_handoff = TRUE` and checks
pass, also includes `registry_stub_path` and `registry_index_path`.

## Examples

``` r
if (FALSE) { # \dontrun{
prepare_study_for_registry(".")
} # }
```
