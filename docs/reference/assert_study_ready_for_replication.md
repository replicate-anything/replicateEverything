# Stop when dependencies are missing before a live replication run

Stop when dependencies are missing before a live replication run

## Usage

``` r
assert_study_ready_for_replication(
  doi,
  meta = NULL,
  repo = NULL,
  folder = NULL,
  install_deps = FALSE,
  engines = NULL
)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.
