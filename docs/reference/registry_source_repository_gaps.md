# Studies in a registry missing paper.source_repository

Reads registry stubs (and falls back to legacy aliases). Used by
[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
summary and maintainer messaging.

## Usage

``` r
registry_source_repository_gaps(registry_root = NULL, index = NULL)
```

## Arguments

- registry_root:

  Path to the registry checkout.

- index:

  Optional index data frame.

## Value

Character vector of study keys (DOI or handle) that are missing a source
repository credit.
