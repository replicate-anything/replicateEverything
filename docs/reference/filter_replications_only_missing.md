# Filter replication entries to those without precomputed artifacts

Filter replication entries to those without precomputed artifacts

## Usage

``` r
filter_replications_only_missing(
  display_reps,
  doi,
  folder = NULL,
  repo = NULL,
  only_missing = FALSE,
  study_root = NULL
)
```

## Arguments

- display_reps:

  List of replication entries.

- doi:

  Paper DOI or lookup key.

- folder:

  Optional registry folder name.

- repo:

  Optional repository slug.

- only_missing:

  When `TRUE`, keep only entries where
  [`replication_artifact_exists()`](https://replicate-anything.github.io/replicateEverything/reference/replication_artifact_exists.md)
  is `FALSE`.

- study_root:

  Optional local study root for direct file checks.
