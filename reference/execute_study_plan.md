# Execute a planned study run (ordered steps, memoized within session)

Execute a planned study run (ordered steps, memoized within session)

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

  Re-run steps even when outputs exist.

- format:

  Whether to include format child in plan (already applied in plan).

- repo:

  Optional registry repo slug.

- folder:

  Optional registry folder.

## Value

List with final step result and named intermediate results.
