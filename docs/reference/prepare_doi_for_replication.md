# Prepare a DOI for replication API calls

Wrapper around
[`resolve_doi_input`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)
that returns the canonical DOI.

## Usage

``` r
prepare_doi_for_replication(doi, location = getwd())
```

## Arguments

- doi:

  Character DOI, DOI URL, study-repo path, `"local"`, or blank.

- location:

  Directory to search for a local study (default
  [`getwd()`](https://rdrr.io/r/base/getwd.html)).

## Value

Character DOI.
