# Format a replication error for user-facing display

Unwraps [`conditionMessage()`](https://rdrr.io/r/base/conditions.html)
and, when present, parent errors and the call that failed.

## Usage

``` r
replication_error_message(x)
```

## Arguments

- x:

  An error condition or character message.

## Value

A single character string suitable for logs or UI.

## Examples

``` r
err <- simpleError("Replication failed", call = quote(run_replication()))
replication_error_message(err)
#> Error in replication_error_message(err): could not find function "replication_error_message"
```
