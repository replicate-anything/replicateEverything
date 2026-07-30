# Write derived `audit_summary.json` (+ RDS) from jobs CSV / audit meta

Write derived `audit_summary.json` (+ RDS) from jobs CSV / audit meta

## Usage

``` r
write_derived_registry_audit_summary(jobs, audit = NULL, registry_root = NULL)
```

## Arguments

- jobs:

  Full jobs data frame.

- audit:

  Optional latest `audit_everything` object (for patience / timestamps /
  missing_source on this write).

- registry_root:

  Registry root.

## Value

Invisibly, list of paths.
