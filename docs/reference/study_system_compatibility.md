# Check yaml-declared dependencies against the local system

Reads `languages:`, `paper.dependencies`, `python_dependencies:`,
`stata_packages:`, and `stata_deps_probe:` from `replication.yml` and
probes this machine only (no installs).

## Usage

``` r
study_system_compatibility(
  doi,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  materialize_study = TRUE,
  include_registry_audit = FALSE
)

study_readiness_audit(...)
```

## Arguments

- doi:

  Study DOI.

- repo, folder:

  Registry row hints.

- registry_root:

  Optional local registry checkout.

- materialize_study:

  Materialize folder-backed study repo for Stata probe scripts.

- include_registry_audit:

  Include latest registry `audit_latest.rds` summary.

## Value

A `study_system_compatibility` list.
