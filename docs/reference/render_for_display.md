# Render a replication and apply formatting for display

Render a replication and apply formatting for display

## Usage

``` r
render_for_display(
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
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

## Examples

``` r
if (FALSE) { # \dontrun{
render_for_display("10.1177/00491241211036161", "fig_1")
} # }
```
