# Bucket audit elapsed seconds into short / medium / slow

Bucket audit elapsed seconds into short / medium / slow

## Usage

``` r
audit_runtime_category(seconds)
```

## Arguments

- seconds:

  Numeric elapsed seconds (scalar or vector; `NA` allowed).

## Value

Character vector of categories (`"short"`, `"medium"`, `"slow"`), or
`NA_character_` when `seconds` is missing.
