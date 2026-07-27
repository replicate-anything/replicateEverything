# Study overview (metadata, steps, related, gaps)

Console overview for a
[`get_study()`](https://replicate-anything.github.io/replicateEverything/reference/get_study.md)
handle: citation fields, step counts, related upstream/downstream
studies, and gap tags. For programmatic access to the same information,
read fields on the handle (e.g. `object$doi`, `object$step_counts`)
rather than parsing this printout.

## Usage

``` r
# S3 method for class 'replicate_study'
summary(object, ...)
```

## Arguments

- object:

  A `replicate_study` from
  [`get_study`](https://replicate-anything.github.io/replicateEverything/reference/get_study.md).

- ...:

  Ignored.

## Value

`object`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
summary(get_study("10.1017/S0003055403000534"))
summary(get_study("10.1257/aer.91.5.1369"))
summary(get_study("rep-template"))
} # }
```
