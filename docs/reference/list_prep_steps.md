# List pipeline prep steps for a paper

Superseded by
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
with `include = "pipeline"`.

## Usage

``` r
list_prep_steps(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI, registry handle, or local study path. Pass `"local"`
  (or `""` / `"."`) to use the study in the current working directory —
  no registry lookup is needed; see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A list of prep step entries.
