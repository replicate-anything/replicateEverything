# Run a single replication or all replications for a paper

Executes a specific replication (figure or table) for a paper, or every
step in the study DAG when `what = "everything"` (transform, table, and
figure steps; format children run only when `format = TRUE`).

## Usage

``` r
run_replication(
  doi,
  what,
  language = NULL,
  given = NULL,
  force = FALSE,
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

  Character. Step or replication identifier (e.g. `"tab_1"`), or
  `"everything"` to run all non-format steps in the study DAG.

- language:

  Optional `"R"`, `"stata"`, or `"python"`. When omitted and the
  replication has only one engine, that engine is used automatically.
  When both R and Stata exist for the same logical id, R is preferred
  unless `language` is set.

- given:

  Assumed-complete steps. For a single step, defaults to `"parents"`
  (immediate parent outputs must exist). For `what = "everything"`,
  defaults to `"nothing"` (run the full upstream DAG). May also be a
  character vector of step ids.

- force:

  Logical. Re-run steps even when outputs already exist.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`. Defaults to
  `FALSE`.

- format:

  Logical or `"if_available"`. Apply display formatting when available.
  When `what = "everything"`, applies to each step in the returned list
  (`FALSE` returns raw analysis objects only).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

For a single replication, the analysis or formatted object. For
`what = "everything"`, a named list of results for every non-format step
in the study DAG (invisibly).

## Details

By default returns the raw analysis object (e.g. a `glm` or `ggplot`).
Set `format = TRUE` or `format = "if_available"` to apply the registered
`format_*` step when `replication.yml` defines one (same step used for
display outputs and Shiny).

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
