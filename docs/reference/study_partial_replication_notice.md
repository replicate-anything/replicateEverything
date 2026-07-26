# Summarize why a study offers only partial replication (yaml + optional audit)

Driven by step `incomplete:` / `requires_engine:` / `blocked_reason:`
fields, optionally enriched with the latest registry `audit_latest.rds`
failures and timeouts. Used by Shiny for a one-shot notice when a study
is selected.

## Usage

``` r
study_partial_replication_notice(
  meta,
  doi = NULL,
  registry_root = NULL,
  include_registry_audit = TRUE
)
```

## Arguments

- meta:

  Parsed replication metadata.

- doi:

  Optional DOI for registry audit lookup.

- registry_root:

  Optional local registry checkout.

- include_registry_audit:

  When `TRUE`, merge latest audit snapshot.

## Value

List with `partial`, `message`, `required_engines`, `incomplete_ids`,
`incomplete_n`, `audit_failed`, `audit_timed_out`.
