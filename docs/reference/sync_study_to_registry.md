# Sync a prepared study into the registry repository (maintainer)

Reads the short registry yaml from the study repository (`registry/` or
`inst/registry/`), copies it to `studies/<folder>.yml` in a registry
checkout, and rebuilds `index.csv` via
[`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md).

## Usage

``` r
sync_study_to_registry(
  location = ".",
  registry_root = NULL,
  audit = FALSE,
  patience = 20,
  install_deps = FALSE,
  verbose = TRUE
)
```

## Arguments

- location:

  Study repo path or GitHub address. Defaults to `"."`.

- registry_root:

  Path to the registry repository root. Defaults to
  `getOption("replicateEverything.registry_root")`.

- audit:

  If `TRUE`, run
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  for this study after sync.

- patience:

  Seconds per replication when `audit = TRUE`.

- install_deps:

  Passed to
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  when `audit = TRUE`.

- verbose:

  Passed to
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  when `audit = TRUE`.

## Value

Invisibly, a list with `stub_path`, `index_updated`, `folder`, and
optional `audit`.

## Details

This is a **maintainer** function. Contributors should run
[`prepare_study_for_registry()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_study_for_registry.md)
and open a pull request; maintainers run this (or
[`refresh_registry()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry.md))
from a local registry checkout.

## Examples

``` r
if (FALSE) { # \dontrun{
options(replicateEverything.registry_root = "../registry")
sync_study_to_registry(".")
} # }
```
