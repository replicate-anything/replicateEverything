# Artifact path relative to study root (primary candidate)

Returns the first displayable path from `outputs:` in `replication.yml`,
otherwise a deprecated `artifact:` fallback, otherwise the type-based
default from
[`default_artifact_path()`](https://replicate-anything.github.io/replicateEverything/reference/default_artifact_path.md).
This is the one rule used by both
[`save_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/save_artifact.md)
(build) and artifact lookup (Shiny), so builds write exactly where
lookup reads.

## Usage

``` r
study_artifact_rel_path(rep)
```

## Arguments

- rep:

  A single replication entry from `replication.yml`.
