# Check yaml-declared dependencies against this machine (no installs)

Reads `languages:`, `paper.dependencies`, `python_dependencies:`,
`stata_packages:`, and `stata_deps_probe:` from the study
`replication.yml` and probes the local R, Python, and Stata stack. Alias
for
[`study_system_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/study_system_compatibility.md).

## Usage

``` r
check_study_compatibility(
  doi,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  materialize_study = TRUE,
  include_registry_audit = FALSE
)
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

A `study_system_compatibility` list with `ready`, `install_needed`, and
per-engine `dependencies`.

## See also

[`install_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_dependencies.md),
[`maintainer_dependency_hint()`](https://replicate-anything.github.io/replicateEverything/reference/maintainer_dependency_hint.md)

## Examples

``` r
if (FALSE) { # \dontrun{
check_study_compatibility("10.1017/S0003055426101749")
} # }
```
