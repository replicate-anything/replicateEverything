# Step display data for Shiny (components of paths of id / label / description)

Step display data for Shiny (components of paths of id / label /
description)

## Usage

``` r
study_dag_display(meta, repo = NULL, folder = NULL)
```

## Arguments

- meta:

  Parsed replication metadata, or a DOI / registry handle.

- repo:

  Optional repository slug when `meta` is a DOI or handle.

- folder:

  Optional registry folder when `meta` is a DOI or handle.

## Value

A list of components; each component is a list of paths; each path is a
list of step display records.
