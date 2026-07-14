# Read one field from a single-row registry index slice

Safe for one-row `data.frame` and `tibble` subsets (always uses
`[[col]][1L]` instead of `$col[[1]]`).

## Usage

``` r
index_row_field(row, col, default = "")
```

## Arguments

- row:

  One-row index data frame.

- col:

  Column name.

- default:

  Value when missing or blank.

## Value

Character scalar.
