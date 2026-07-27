# Compact print for a study descriptor

Prints title and DOI/handle; points to
[`summary()`](https://rdrr.io/r/base/summary.html) for the full
overview. See
[`get_study()`](https://replicate-anything.github.io/replicateEverything/reference/get_study.md)
for field access and passing keys to other verbs.

## Usage

``` r
# S3 method for class 'replicate_study'
print(x, ...)
```

## Arguments

- x:

  A `replicate_study` object.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
get_study("10.1017/S0003055403000534")
get_study("rep-template")
} # }
```
