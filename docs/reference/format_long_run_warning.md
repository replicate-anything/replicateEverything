# Format a lengthy user-facing warning for audit-timeout / long Runs

Format a lengthy user-facing warning for audit-timeout / long Runs

## Usage

``` r
format_long_run_warning(
  timeout_seconds = NA_real_,
  seconds = NA_real_,
  bake_seconds = NA_real_
)
```

## Arguments

- timeout_seconds:

  Audit patience / cap in seconds when known.

- seconds:

  Elapsed seconds from the audit row (often equals the cap).

## Value

Character scalar.
