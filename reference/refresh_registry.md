# Refresh the registry index and optionally rerun the full audit (maintainer)

Recompiles `index.csv` from all `studies/*.yml` stubs, then optionally
runs
[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
across the registry.

## Usage

``` r
refresh_registry(
  registry_root = NULL,
  audit = TRUE,
  patience = 20,
  install_deps = FALSE,
  verbose = TRUE,
  substantive = TRUE
)
```

## Arguments

- registry_root:

  Path to the registry repository root.

- audit:

  If `TRUE`, run
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  after rebuilding the index.

- patience:

  Seconds per replication when auditing.

- install_deps:

  Passed to
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md).

- verbose:

  Passed to
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md).

- substantive:

  Passed to
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md).

## Value

Invisibly, a list with `index` and optional `audit`.

## Examples

``` r
if (FALSE) { # \dontrun{
options(replicateEverything.registry_root = "../registry")
refresh_registry(audit = TRUE)
} # }
```
