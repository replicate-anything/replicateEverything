# Add a folder-backed study to the replication registry (maintainer)

Validates a folder-backed study with
[`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md),
ensures registry handoff files exist (via
[`write_study_registry_stub()`](https://replicate-anything.github.io/replicateEverything/reference/write_study_registry_stub.md)
when missing), then installs the stub in a registry checkout via
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md).

## Usage

``` r
add_folder_paper(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  build_artifacts = FALSE,
  install_deps = TRUE,
  audit = FALSE
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
  [`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)
  before checks.

- install_deps:

  Passed to
  [`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md).

- audit:

  If `TRUE`, run
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  for this study after sync.

## Value

Invisibly, the result of
[`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md),
with `stub_path` and `index_updated` when registration succeeds.

## Details

Contributors should run
[`prepare_study_for_registry()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_study_for_registry.md)
and open a pull request. Maintainers use this function (or
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
directly) from a local registry checkout.
