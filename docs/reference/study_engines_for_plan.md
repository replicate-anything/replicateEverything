# Engines required to execute a planned study run (excludes format-only steps)

Engines required to execute a planned study run (excludes format-only
steps)

## Usage

``` r
study_engines_for_plan(meta, plan)
```

## Arguments

- meta:

  Parsed replication metadata.

- plan:

  Output of
  [`plan_study_run()`](https://replicate-anything.github.io/replicateEverything/reference/plan_study_run.md).

## Value

Character vector subset of `r`, `stata`, `python`.
