# Text representation of the study DAG for Shiny / CLI

Text representation of the study DAG for Shiny / CLI

## Usage

``` r
describe_study_dag(meta, repo = NULL, folder = NULL)
```

## Arguments

- meta:

  Parsed replication metadata, or a DOI / registry handle. Pass
  `"local"` to describe the study in the current working directory (no
  registry lookup needed; see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)).

- repo:

  Optional repository slug when `meta` is a DOI or handle.

- folder:

  Optional registry folder when `meta` is a DOI or handle.

## Value

Character vector of component strings.

## Examples

``` r
if (FALSE) { # \dontrun{
describe_study_dag("10.1177/00491241211036161")

# setwd() to a checked-out study repo (or open its RStudio project) and
# sanity-check the parsed DAG without any registry — no DOI needed.
setwd("path/to/rep-my-study")
describe_study_dag("local")
} # }
```
