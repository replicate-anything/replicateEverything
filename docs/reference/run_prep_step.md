# Run a single prep step

Executes a pipeline step (Stata, R, or Python), writes `output` when
configured, and returns a preview object (typically the head of a data
frame).

## Usage

``` r
run_prep_step(
  doi,
  what,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  force = FALSE
)
```

## Arguments

- doi:

  Character. DOI, registry handle, or local study path (see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)).
  Pass `"local"` to run against the study in the current working
  directory — no registry lookup is needed.

- what:

  Prep step id (e.g. `"construct_analysis_dataset"`).

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

- force:

  Logical. Re-run steps even when declared `outputs/` already exist.
  Defaults to `TRUE`:
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  is a live Run (unlike Display /
  [`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md),
  which use precomputed files). Set `force = FALSE` to reuse existing
  upstream outputs when present; the target step still recomputes.

## Value

A data preview, file path character vector, or replication result.
