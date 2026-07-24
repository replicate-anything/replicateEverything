# Validate then sync a study into the registry (maintainer)

Runs
[`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md)
then
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md).
Use when a maintainer has a study checkout and a local registry
checkout.

## Usage

``` r
register_study(
  location = ".",
  build_artifacts = FALSE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  audit = FALSE
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

- dry_run:

  If `TRUE`, run checks only; do not write registry files.

- audit:

  If `TRUE`, run
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  for this study after sync.

## Value

Invisibly, the checklist result; when registration succeeds, also
includes `stub_path` and `index_updated`.
