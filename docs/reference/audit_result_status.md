# User-facing status label for one audit result row

Maps success / timeout / skipped flags to `"OK"`, `"Timed out"`,
`"Failed"`, or `"Skipped"`. Used by registry audit reports and the
package audit vignette.

## Usage

``` r
audit_result_status(success, timed_out = FALSE, skipped = FALSE)
```

## Arguments

- success:

  Logical vector of success flags (`NA` allowed).

- timed_out:

  Logical vector of timeout flags.

- skipped:

  Logical vector of skip flags (incomplete / blocked steps).

## Value

Character vector of status labels, same length as the inputs.
