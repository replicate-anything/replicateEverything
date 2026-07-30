# Resolve a study handle (metadata once)

Returns a compact `replicate_study` **handle**: registry index fields
plus step counts, related studies, and gap tags from the study
`replication.yml`, resolved once. Pass a journal DOI, registry handle
(e.g. `"rep-template"`), or `"local"` / a study path (see
[`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)).

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

## Details

Besides
[`summary.replicate_study`](https://replicate-anything.github.io/replicateEverything/reference/summary.replicate_study.md)
/
[`summary_study()`](https://replicate-anything.github.io/replicateEverything/reference/summary_study.md)
for a console overview, use the handle to:

- Inspect fields programmatically (`st$doi`, `st$handle`, `st$title`,
  `st$languages`, `st$step_counts`, `st$related`, `st$gaps`, `st$repo`,
  ...).

- Feed DOI / handle strings into other consumer verbs — e.g.
  [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md),
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md),
  [`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md)
  (via a local path),
  [`describe_study_dag()`](https://replicate-anything.github.io/replicateEverything/reference/describe_study_dag.md),
  [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
  — which take character keys, not the handle object itself:
  `list_replications(st$doi)` or `describe_study_dag(st$handle)`.

- Filter or join against
  [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)
  /
  [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
  results, or share the same resolved context with Shiny / reports.

## See also

[`summary.replicate_study()`](https://replicate-anything.github.io/replicateEverything/reference/summary.replicate_study.md),
[`summary_study()`](https://replicate-anything.github.io/replicateEverything/reference/summary_study.md),
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md),
[`describe_study_dag()`](https://replicate-anything.github.io/replicateEverything/reference/describe_study_dag.md),
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md),
[`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Fearon & Laitin (APSR 2003)
st <- get_study("10.1017/S0003055403000534")
summary(st)
st$doi
st$languages
st$step_counts
list_replications(st$doi)
describe_study_dag(st$doi)

# Blair et al. (APSR 2022); Acemoglu et al. (AER 2001); template handle
get_study("10.1017/S0003055422000284")
get_study("10.1257/aer.91.5.1369")
get_study("rep-template")

# Reanalysis handle (no journal DOI on the extension itself)
summary_study("rep-10.1017-S0003055403000534--alt-1")
} # }
```
