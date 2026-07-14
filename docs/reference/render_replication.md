# Render a single replication

Loads data, sources the replication script, and returns a typed result
envelope suitable for Shiny display or artifact generation.

## Usage

``` r
render_replication(
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  skip_prep = FALSE,
  force = FALSE,
  meta = NULL,
  ctx = NULL,
  engines = NULL
)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (logical id, e.g. `"tab_1"`).

- language:

  Optional `"R"` or `"stata"`.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A list with `id`, `type`, `object`, and `format`.

## Examples

``` r
if (FALSE) { # \dontrun{
render_replication("10.1177/00491241211036161", "fig_1")
render_replication("10.1017/S0003055403000534", "tab_1", language = "stata")
} # }
```
