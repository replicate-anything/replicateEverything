# Run one replication with a per-object time limit

Run one replication with a per-object time limit

## Usage

``` r
audit_run_one(
  doi,
  what,
  engine = NULL,
  patience = 20,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  substantive = TRUE
)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (logical id, e.g. `"tab_1"`).

- patience:

  Seconds before halting the run (default 20). This is the audit cap
  applied via `setTimeLimit`; for Stata, the processx wait is also
  aligned to this cap so overdue batch jobs are killed cleanly.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

List with `success`, `seconds`, `timed_out`, `timeout_seconds`, and
`error`.
