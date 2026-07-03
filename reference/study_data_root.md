# Root directory for external study data

Uses `ctx$study_data_root`, then
`getOption("replicateEverything.study_data_root")`, then
[`getwd()`](https://rdrr.io/r/base/getwd.html).

## Usage

``` r
study_data_root(ctx = NULL)
```

## Arguments

- ctx:

  Optional paper context.

## Value

Normalized path.
