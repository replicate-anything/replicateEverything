# Escape one field for Shiny feedback CSV output

Prefixes formula-injection starters with a single quote; quotes fields
that contain commas, quotes, or newlines.

## Usage

``` r
escape_shiny_feedback_csv_field(x)
```

## Arguments

- x:

  Character scalar.

## Value

Escaped character scalar.
