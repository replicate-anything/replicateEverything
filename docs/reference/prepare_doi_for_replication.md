# Prepare a DOI for replication API calls

Wrapper around
[`resolve_doi_input`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)
that returns the canonical DOI.

## Usage

``` r
prepare_doi_for_replication(doi, location = getwd(), allow_local = TRUE)
```

## Arguments

- doi:

  Character DOI, DOI URL, study-repo path, `"local"`, or blank.

- location:

  Directory to search for a local study (default
  [`getwd()`](https://rdrr.io/r/base/getwd.html)).

- allow_local:

  When `FALSE`, never treat blank/`local`/`.` as a working-directory
  study (used by
  [`install_registry_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_registry_dependencies.md)).

## Value

Character DOI.
