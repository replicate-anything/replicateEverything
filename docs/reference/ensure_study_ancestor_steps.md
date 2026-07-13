# Run missing upstream DAG steps before a display replication

When a study uses the unified `steps:` block, display steps declare
`parents:` rather than legacy `requires:`. This runs any ancestor
transform steps whose outputs are not yet present.

## Usage

``` r
ensure_study_ancestor_steps(
  meta,
  rep,
  ctx,
  doi,
  install_deps = FALSE,
  force = FALSE,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- meta:

  Parsed metadata.

- rep:

  Replication entry.

- ctx:

  Paper context.

- doi:

  Study DOI or handle.

- install_deps:

  Passed to step runners.

- force:

  Re-run steps even when outputs exist.

- repo:

  Optional registry repo slug.

- folder:

  Optional registry folder.
