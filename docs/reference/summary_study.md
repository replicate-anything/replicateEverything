# Summarize a study by DOI / handle (constructs then summarizes)

Convenience wrapper around `summary(get_study(doi))`.

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
