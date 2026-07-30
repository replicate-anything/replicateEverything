# Declared displayable `outputs:` paths only (no type-based fallbacks)

Used when Display should stack every panel listed under `outputs:` (e.g.
multi-panel figures).
[`study_artifact_rel_candidates()`](https://replicate-anything.github.io/replicateEverything/reference/study_artifact_rel_candidates.md)
still appends type defaults for single-artifact lookup / bake.

## Usage

``` r
study_declared_displayable_rels(rep)
```

## Arguments

- rep:

  A single replication entry from `replication.yml`.
