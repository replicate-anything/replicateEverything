# Add a package-backed study to the replication registry

Validates a study replication package with
[`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md),
then writes a lightweight registry stub (`studies/<folder>.yml`) and
updates `index.csv`.

## Usage

``` r
add_paper(
  location,
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE
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

## Value

Invisibly, the result of
[`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md),
with `stub_path` and `index_updated` when registration succeeds.

## Details

Package-backed studies do **not** copy code, data, or artifacts into the
registry. Those live in the study package (`inst/report/artifacts/` from
`build_report()`).
