# Load a study descriptor for summary and related links

Returns a compact `replicate_study` object from the registry index and
study `replication.yml`. Use with
[`summary.replicate_study`](https://replicate-anything.github.io/replicateEverything/reference/summary.replicate_study.md)
for a console overview (metadata, step counts, related studies, gap
tags).

## Usage

``` r
get_study(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI, registry handle, or `"local"` / study path (see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

An object of class `replicate_study`.

## See also

[`summary.replicate_study()`](https://replicate-anything.github.io/replicateEverything/reference/summary.replicate_study.md),
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md),
[`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)

## Examples

``` r
if (FALSE) { # \dontrun{
st <- get_study("10.1017/S0003055403000534")
summary(st)
summary_study("rep-10.1017-S0003055403000534--alt-1")
} # }
```
