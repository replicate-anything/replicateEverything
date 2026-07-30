# Progress-bar category for one audit result row

Mutually exclusive buckets for the Shiny registry health bar:
`replicating`, `timed_out`, `substantive_fail`, `missing_engine`, or
`other` (gaps / skipped / incomplete / data unavailable / other fails).

## Usage

``` r
audit_progress_category(
  success = NA,
  timed_out = FALSE,
  skipped = FALSE,
  substantive_ok = NA,
  error_snippet = ""
)
```

## Arguments

- success:

  Logical success flag (`NA` allowed for skipped rows).

- timed_out:

  Logical timeout flag.

- skipped:

  Logical skip flag.

- substantive_ok:

  Logical or `NA` substantive-check result.

- error_snippet:

  Character skip / error reason.

## Value

Character scalar category id.
