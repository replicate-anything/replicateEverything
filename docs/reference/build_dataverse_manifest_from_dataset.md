# Build manifest rows from a Dataverse dataset inventory

Tabular files map `path` to `originalFileName` when present (author
layout); otherwise to the listed filename.

## Usage

``` r
build_dataverse_manifest_from_dataset(
  dataset,
  server = "dataverse.harvard.edu",
  paths = NULL
)
```

## Arguments

- dataset:

  Dataverse dataset DOI or persistent id.

- server:

  Dataverse host.

- paths:

  Optional character vector of Dataverse filenames to include.

## Value

Data frame with columns `id`, `path`, `dataverse_file`, `original`.
