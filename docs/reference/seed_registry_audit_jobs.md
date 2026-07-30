# Seed / refresh audit jobs CSV from bake timings, artifacts, and prior RDS

Populates missing study×step rows so the health bar is not empty before
the first full portfolio audit. Existing `source = "audit"` rows are
kept; bake/artifact rows only fill gaps (or refresh provisional bake
rows).

## Usage

``` r
seed_registry_audit_jobs(
  registry_root = NULL,
  index = NULL,
  from_rds = TRUE,
  from_bake = TRUE,
  verbose = TRUE
)
```

## Arguments

- registry_root:

  Optional registry root.

- index:

  Optional registry index (default
  [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)).

- from_rds:

  If `TRUE`, migrate rows from `audit_latest.rds` when present.

- from_bake:

  If `TRUE`, add provisional ok rows from bake timings / local artifacts
  for jobs not yet in the CSV.

- verbose:

  Print progress.

## Value

Invisibly, list with `jobs` path, row counts, and summary paths.
