# Incremental registry audit job store (`audit_jobs.csv`)

Flat CSV of per-job audit rows.
[`write_registry_audit_record()`](https://replicate-anything.github.io/replicateEverything/reference/write_registry_audit_record.md)
upserts audited jobs and rebuilds derived `audit_summary.json` from the
**full** CSV so a one-DOI audit never wipes the portfolio health bar.
