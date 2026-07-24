# Faceted pipeline groups for Shiny (split multi-branch components)

Faceted pipeline groups for Shiny (split multi-branch components)

## Usage

``` r
study_dag_facets(meta, repo = NULL, folder = NULL)
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

List of facets, each with `title` and `paths`.
