# Whether a Shiny step is suitable for default selection on study open

Prefer steps where Display would work: baked output present, or a normal
runnable step (not `data_unavailable:` / missing-engine / incomplete
with no displayable output).

## Usage

``` r
shiny_step_default_available(
  entry,
  output_exists = FALSE,
  audit_skipped_engine = FALSE,
  engine_available = NULL
)
```

## Arguments

- entry:

  Step list (yaml entry or Shiny row fields as a list).

- output_exists:

  Whether a display artifact exists.

- audit_skipped_engine:

  Passed to
  [`classify_shiny_run_gap()`](https://replicate-anything.github.io/replicateEverything/reference/classify_shiny_run_gap.md).

- engine_available:

  Passed to
  [`classify_shiny_run_gap()`](https://replicate-anything.github.io/replicateEverything/reference/classify_shiny_run_gap.md).

## Value

Logical.
