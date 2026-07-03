# Write audit results into the registry repository

Writes `audit_summary.json` for Shiny and lightweight consumers, and
`audit_latest.rds` with the full `audit_everything` object.

## Usage

``` r
write_registry_audit_record(audit, registry_root = NULL)
```

## Arguments

- audit:

  An `audit_everything` object.

- registry_root:

  Registry repository root.

## Value

Invisibly, a list with paths `summary` and `rds`.
