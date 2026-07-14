# Canonical lookup key (DOI or study handle) from paper metadata

Used when a study has no DOI (reanalysis / extension repos) or when
validating registry stubs that only declare `study_handle`.

## Usage

``` r
study_lookup_from_paper(paper, folder = NULL)
```

## Arguments

- paper:

  `paper` list from replication metadata.

- folder:

  Optional registry folder name fallback.

## Value

Character lookup key.
