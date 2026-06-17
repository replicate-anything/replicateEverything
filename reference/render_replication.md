# Render a single replication

Loads data, sources the replication script, and returns a typed result
envelope suitable for Shiny display or artifact generation.

## Usage

``` r
render_replication(doi, what, install_deps = FALSE, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., `"fig_1"`).

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A list with `id`, `type`, `object`, and `format`.
