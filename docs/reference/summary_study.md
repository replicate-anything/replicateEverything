# Summarize a study by DOI / handle (constructs then summarizes)

Convenience wrapper around `summary(get_study(doi))`. Prefer
[`get_study()`](https://replicate-anything.github.io/replicateEverything/reference/get_study.md)
when you need the handle for field access or downstream verbs; use this
when you only want the printed overview.

## Usage

``` r
summary_study(doi, repo = NULL, folder = NULL, ...)
```

## Arguments

- doi:

  Character. DOI, registry handle, or `"local"` / study path (see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

- ...:

  Passed to
  [`summary.replicate_study`](https://replicate-anything.github.io/replicateEverything/reference/summary.replicate_study.md).

## Value

Invisibly, the `replicate_study` object.

## See also

[`get_study()`](https://replicate-anything.github.io/replicateEverything/reference/get_study.md),
[`summary.replicate_study()`](https://replicate-anything.github.io/replicateEverything/reference/summary.replicate_study.md)

## Examples

``` r
if (FALSE) { # \dontrun{
summary_study("10.1017/S0003055403000534")
summary_study("10.1017/S0003055422000284")
summary_study("10.1257/aer.91.5.1369")
summary_study("rep-template")
summary_study("rep-10.1017-S0003055403000534--alt-1")
} # }
```
