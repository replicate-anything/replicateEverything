# Resolve a DOI or local study query into a canonical DOI

When `doi` is blank or `"local"`, searches for `replication.yml` from
the working directory upward. When `doi` is a filesystem path, searches
that folder (and parents). When a matching local study is found,
registers it via
[`configure_study_folder`](https://replicate-anything.github.io/replicateEverything/reference/configure_study_folder.md).

## Usage

``` r
resolve_doi_input(doi = NULL, location = getwd(), allow_local = TRUE)
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

A list with `doi`, `local_root`, and `is_local`.
