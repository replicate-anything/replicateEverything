# Refresh registry derived files (maintainer; light by default)

Light path (`audit = FALSE`, default):

1. Rebuild `index.csv` from `studies/*.yml` stubs
2. Rebuild `shiny_studies.json` (via internal `build_registry_index()`)
3. Seed `audit_jobs.csv` gaps from bake timings / artifacts / prior RDS
   (no live engines)
4. Rebuild `audit_summary.json` / `audit_latest.rds` (Shiny health bar)

Heavy path: set `audit = TRUE` for a full live
[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md),
or pass a character vector of DOIs/handles to audit only those studies. Live
audit always runs after the light path and refreshes the derived summary.

## Usage

``` r
refresh_registry(
  registry_root = NULL,
  audit = FALSE,
  patience = 20,
  install_deps = FALSE,
  verbose = TRUE,
  substantive = TRUE,
  seed = TRUE
)
```

## Arguments

- registry_root:

  Path to the registry repository root.

- audit:

  `FALSE` (default) for light refresh only; `TRUE` for a full live audit; or a
  character vector of DOIs/handles for a subset audit.

- patience:

  Seconds per replication when auditing.

- install_deps:

  Passed to
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md).

- verbose:

  Passed to seed /
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md).

- substantive:

  Passed to
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md).

- seed:

  If `TRUE` (default), fill audit CSV gaps before rebuilding the summary. Set
  `FALSE` to rebuild the summary from the existing CSV only.

## Value

Invisibly, a list with `index`, optional `seed`, and optional `audit`.

## Examples

``` r
if (FALSE) { # \dontrun{
options(replicateEverything.registry_root = "../registry")
refresh_registry()
refresh_registry(audit = TRUE, patience = 20)
refresh_registry(audit = "10.1177/00491241211036161")
} # }
```
