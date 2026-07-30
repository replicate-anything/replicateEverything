# Convert audit results data frame rows into CSV job rows

Convert audit results data frame rows into CSV job rows

## Usage

``` r
audit_results_to_jobs_rows(
  results,
  checked_at,
  source = "audit",
  prior_jobs = NULL
)
```

## Arguments

- results:

  Audit results data frame.

- checked_at:

  POSIXct or character UTC timestamp for this write.

- source:

  Provenance label (`"audit"`, `"bake"`, ...).

- prior_jobs:

  Optional existing jobs (to preserve `last_success_at`).

## Value

Normalized jobs data frame.
