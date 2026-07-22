# Add a package-backed study to the replication registry (maintainer)

Validates a study replication package with
[`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md),
then installs a stub built from the study `replication.yml` into a
registry checkout via
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md).
Stub files are written only under the registry repository — not into the
study package.

## Usage

``` r
add_paper(
  location,
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  audit = FALSE
)
```

## Arguments

- location:

  Local package path or GitHub address (`org/repo` or URL).

- full_replication:

  If `TRUE`, also run every table and figure live.

- registry_root:

  Path to the registry repository root (contains `studies/` and
  `index.csv`). Defaults to
  `getOption("replicateEverything.registry_root")`.

- dry_run:

  If `TRUE`, run checks only; do not write registry files.

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
(validate / build). Maintainers use this function from a local registry
checkout.

Package-backed studies do **not** copy code, data, or artifacts into the
registry. Those live in the study package (`inst/report/artifacts/` from
`build_report()`).
