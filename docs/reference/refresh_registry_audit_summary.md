# Rebuild `audit_summary.json` from the full audit jobs CSV

Does not re-run audits. Use after manual CSV edits or after
[`seed_registry_audit_jobs()`](https://replicate-anything.github.io/replicateEverything/reference/seed_registry_audit_jobs.md).

## Usage

``` r
refresh_registry_audit_summary(registry_root = NULL)
```

## Arguments

- registry_root:

  Optional registry repository root.

## Value

Invisibly, a list with paths `summary`, `rds`, `jobs`.
