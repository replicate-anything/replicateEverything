# Execute a planned study run (ordered steps, memoized within session)

The **target** step always runs live. When `force = FALSE`, non-target
upstream steps whose declared `outputs/` already exist are skipped
(message: "Using existing output for step").
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
defaults to `force = TRUE` so a Run recomputes; Display uses
[`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md).

## Usage

``` r
execute_study_plan(
  plan,
  doi,
  meta,
  ctx,
  language = NULL,
  install_deps = FALSE,
  force = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- plan:

  Output of
  [`plan_study_run()`](https://replicate-anything.github.io/replicateEverything/reference/plan_study_run.md).

- doi:

  Study DOI or local path.

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

- language:

  Optional engine for display steps.

- install_deps:

  Passed to
  [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md).

- force:

  Re-run upstream steps even when outputs exist. The target always
  re-runs regardless of this flag.

- format:

  Whether to include format child in plan (already applied in plan).

- repo:

  Optional registry repo slug.

- folder:

  Optional registry folder.

## Value

List with final step result and named intermediate results.
