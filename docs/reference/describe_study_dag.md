# Text representation of the study DAG for Shiny / CLI

Text representation of the study DAG for Shiny / CLI

## Usage

``` r
describe_study_dag(meta, repo = NULL, folder = NULL)
```

## Arguments

- meta:

  Parsed replication metadata, or a DOI / registry handle.

- repo:

  Optional repository slug when `meta` is a DOI or handle.

- folder:

  Optional registry folder when `meta` is a DOI or handle.

## Value

Character vector of component strings.
