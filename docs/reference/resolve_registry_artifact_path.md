# Resolve a precomputed artifact under the registry study folder

The artifact location comes from a single rule –
[`study_artifact_rel_path()`](https://replicate-anything.github.io/replicateEverything/reference/study_artifact_rel_path.md)
(first displayable path from `outputs:` in `replication.yml`, or the
type-based default). Builds write to that same path, so lookup is
deterministic: return the local file when present, otherwise the registry
URL. Availability of the remote file is decided by the actual fetch in
[`load_artifact_file_path()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact_file_path.md),
not by a separate existence probe.

## Usage

``` r
resolve_registry_artifact_path(what, ctx, rep = NULL, doi = NULL)
```

## Arguments

- what:

  Replication id (used only when `rep` is unavailable).

- ctx:

  Paper context.

- rep:

  Replication entry from `replication.yml`.

- doi:

  Unused; retained for backward compatibility.

## Details

Package-backed studies ship display artifacts on the study package and
are resolved elsewhere (see
[`get_artifact_path()`](https://replicate-anything.github.io/replicateEverything/reference/get_artifact_path.md)).
