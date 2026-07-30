# Named progress counts for the registry health bar

Prefers classifying rows from a full audit results data frame. When only
a summary list is available, reconstructs counts from summary fields
(`success`, `timed_out`, `substantive_failed`, `missing_engine`,
`failed`, `skipped`).

## Usage

``` r
audit_progress_counts(summary = NULL, results = NULL)
```

## Arguments

- summary:

  Optional audit summary list (from `audit_summary.json`).

- results:

  Optional audit results data frame.

## Value

Named integer vector with categories `replicating`, `timed_out`,
`substantive_fail`, `missing_engine`, `other`, plus `total`.
