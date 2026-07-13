# Study subfolder name under deployed `data/`

Uses `paper.study_folder` from `replication.yml` when set, otherwise
[`study_folder_from_doi()`](https://replicate-anything.github.io/replicateEverything/reference/study_folder_from_doi.md)
(`rep-10.x-y` with hyphens).

## Usage

``` r
study_data_folder_name(meta, ctx = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Optional paper context.

## Value

Character scalar.
