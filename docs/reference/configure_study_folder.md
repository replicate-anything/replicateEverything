# Register a server-local study folder for a DOI

Sets `replicateEverything.study_folders` under every alias the package
uses for lookups (registry folder name, `rep-<doi>`, etc.).

## Usage

``` r
configure_study_folder(doi, path)
```

## Arguments

- doi:

  Character DOI.

- path:

  Absolute path to the study root (must contain `replication.yml`).

## Value

Invisibly, the normalized path.
