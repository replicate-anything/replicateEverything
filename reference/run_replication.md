# Run a single replication or all replications for a paper

Executes a specific replication (figure or table) for a paper, or every
logical group when `what = "everything"`.

## Usage

``` r
run_replication(
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- doi:

  Character. DOI, registry handle, or local study path (see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)).

- what:

  Character. Replication identifier (logical id, e.g. `"tab_1"`), or
  `"everything"` to run all tables and figures.

- language:

  Optional `"R"` or `"stata"`. Defaults to R when both engines exist for
  the same logical replication.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

- format:

  Logical or `"if_available"`. Apply display formatting when available.
  Ignored when `what = "everything"` unless set explicitly.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

For a single replication, the analysis or formatted object. For
`what = "everything"`, a named list of such objects (invisibly).

## Details

By default returns the raw analysis object (e.g. a `glm` or `ggplot`).
Set `format = TRUE` or `format = "if_available"` to apply the registered
`format_*` step when `replication.yml` defines one (same step used for
display artifacts and Shiny).

## Examples

``` r
if (FALSE) { # \dontrun{
run_replication("10.1177/00491241211036161", "fig_1")
run_replication("bounding-causes", "fig_1")
run_replication("10.1017/S0003055403000534", "tab_1", format = TRUE)
run_replication("10.1017/S0003055403000534", "tab_1", language = "stata")
run_replication("10.1177/00491241211036161", "everything")
} # }
```
