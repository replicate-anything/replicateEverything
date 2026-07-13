# Run pipeline prep steps during artifact builds

Run pipeline prep steps during artifact builds

## Usage

``` r
run_build_prep_steps(
  meta,
  ctx,
  doi,
  prep_steps,
  install_deps = FALSE,
  force = FALSE,
  study_root = NULL
)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

- doi:

  Normalized DOI.

- prep_steps:

  List of prep entries to run.

- install_deps:

  Passed to
  [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md).

- force:

  Re-run prep even when outputs already exist.

- study_root:

  Optional study or package root for portable manifest paths.

## Value

List with `statuses` (named list) and `failures`.
