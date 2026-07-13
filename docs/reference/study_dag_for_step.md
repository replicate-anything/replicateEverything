# Pipeline paths leading to one step (for Shiny Pipeline tab)

Pipeline paths leading to one step (for Shiny Pipeline tab)

## Usage

``` r
study_dag_for_step(meta, step_id, repo = NULL, folder = NULL)
```

## Arguments

- meta:

  Parsed replication metadata, or a DOI / registry handle.

- step_id:

  Step or replication group id (e.g. `"tab_1"`).

- repo:

  Optional repository slug when `meta` is a DOI or handle.

- folder:

  Optional registry folder when `meta` is a DOI or handle.

## Value

List of paths; each path is a list of display node records.
