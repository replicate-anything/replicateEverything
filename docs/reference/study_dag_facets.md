# Faceted pipeline groups for Shiny (split multi-branch components)

Faceted pipeline groups for Shiny (split multi-branch components)

## Usage

``` r
study_dag_facets(meta, repo = NULL, folder = NULL)
```

## Arguments

- meta:

  Parsed replication metadata, or a DOI / registry handle.

- repo:

  Optional repository slug when `meta` is a DOI or handle.

- folder:

  Optional registry folder when `meta` is a DOI or handle.

## Value

List of facets, each with `title` and `paths`.
