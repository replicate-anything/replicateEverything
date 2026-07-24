# List available replications for a paper

Returns step entries from `replication.yml`: tables, figures, and (when
requested) pipeline transforms. Use `grouped = TRUE` for one entry per
logical product (e.g. a single `tab_1` when both R and Stata exist).

## Usage

``` r
list_replications(
  doi,
  repo = NULL,
  folder = NULL,
  grouped = FALSE,
  language = NULL,
  include = c("display", "pipeline", "all")
)
```

## Arguments

- doi:

  Character. DOI, registry handle, or local study path. Pass `"local"`
  (or `""` / `"."`) to use the study in the current working directory —
  no registry lookup is needed; see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

- grouped:

  Logical. When `TRUE`, return one entry per logical table/figure group
  (R preferred when `language` is unset).

- language:

  Optional `"R"`, `"stata"`, or `"python"` when `grouped = TRUE`.

- include:

  Which steps to return: `"display"` (tables and figures, default),
  `"pipeline"` (transform / prep steps), or `"all"` (every non-format
  step).

## Value

A `replication_list` object (a list with a compact
[`print()`](https://rdrr.io/r/base/print.html) method).

## Examples

``` r
if (FALSE) { # \dontrun{
list_replications("10.1177/00491241211036161")
list_replications("10.1257/aer.91.5.1369", grouped = TRUE)
list_replications("10.1257/aer.91.5.1369", grouped = TRUE, language = "stata")
list_replications("10.1017/s0003055426101749", include = "pipeline")

# Working on a study repo checked out locally: setwd() to the study repo
# root (or open its RStudio project), then use "local" — no registry or
# DOI lookup required.
setwd("path/to/rep-my-study")
list_replications("local")
list_replications("local", grouped = TRUE)
} # }
```
