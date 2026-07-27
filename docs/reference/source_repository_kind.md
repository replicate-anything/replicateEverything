# Classify a source-repository credit for display icons

Heuristics from the URL / credit string. Authors only need to set
`paper.source_repository`; optional explicit kinds are not required.

## Usage

``` r
source_repository_kind(value)
```

## Arguments

- value:

  Character URL or short credit from
  [`paper_source_repository()`](https://replicate-anything.github.io/replicateEverything/reference/paper_source_repository.md).

## Value

One of `"dataverse"`, `"osf"`, `"worldbank"`, `"icpsr"`, `"git"`,
`"personal"`, `"replicateEverything"`, or `"other"`.
