# Write audit results into the registry repository

Upserts this audit's jobs into flat `audit_jobs.csv` (by doi × object ×
engine), then rebuilds derived `audit_summary.json` and
`audit_latest.rds` from the **full** CSV so a one-DOI audit never wipes
the portfolio health bar.

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

Invisibly, a list with paths `summary`, `rds`, and `jobs`.

## Details

`last_success_at` is set to the audit finish time on success; otherwise
the prior CSV value is kept, with bake-timing / artifact-mtime fallback.

## See also

[`refresh_registry_audit_summary()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry_audit_summary.md),
[`seed_registry_audit_jobs()`](https://replicate-anything.github.io/replicateEverything/reference/seed_registry_audit_jobs.md)
