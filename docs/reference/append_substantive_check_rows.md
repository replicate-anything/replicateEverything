# Add substantive-check rows to a replication checklist

Submitters should add `tests/substantive/<step_id>.R` when published
benchmarks are available. Maintainers see coverage here and in
[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
(`substantive = TRUE`).

## Usage

``` r
append_substantive_check_rows(
  checks,
  study_root,
  display_reps,
  objects = NULL,
  doi = NULL
)
```

## Arguments

- checks:

  Existing checklist data frame from
  [`bind_check_results()`](https://replicate-anything.github.io/replicateEverything/reference/bind_check_results.md).

- study_root:

  Study repository root.

- display_reps:

  Display replication entries (tables and figures).

- objects:

  Optional named list of analysis objects from live runs (step id →
  object). When provided, defined checks are executed.

- doi:

  Study DOI for
  [`run_substantive_check()`](https://replicate-anything.github.io/replicateEverything/reference/run_substantive_check.md).
