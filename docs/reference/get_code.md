# Retrieve replication code for a paper

Returns a single script suitable for the Code tab in Shiny. For Stata
replications, the substantive analysis from `stata_source` is inlined
after a short setup section so the script can be copied and run. When
`stata_source` is omitted but the runner calls nested `do` files, those
paths are inferred automatically (setup helpers such as
`init_study_paths.do` are skipped). R replications return the analysis
script only; optional `format_*` helpers in separate files are labeled
and omitted for Stata.

## Usage

``` r
get_code(
  doi,
  what,
  language = NULL,
  style = c("inline", "source"),
  mode = c("definitions", "run"),
  repo = NULL,
  folder = NULL
)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (logical id).

- language:

  Optional `"R"` or `"stata"`.

- style:

  Display style: `"inline"` (default, inlines Stata sources for
  copy-paste) or `"source"` (raw runner only, for linked inspection in
  Shiny).

- mode:

  `"definitions"` (default) returns the stored script (pure function
  definitions). `"run"` appends a yaml-implied execute recipe (load
  `data:`, call `make_*`, pipe `format_*` when applicable).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A character vector containing the lines of the replication script(s).

## Details

Scripts keep pure `make_*` / `format_*` definitions; the package
orchestrates load \\\rightarrow\\ make \\\rightarrow\\ format via
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
using `replication.yml` as the single source of truth. Authors do not
need an interactive
[`sys.nframe()`](https://rdrr.io/r/base/sys.parent.html) footer. Use
`mode = "run"` when you want script text that appends a yaml-implied
load \\\rightarrow\\ make \\\rightarrow\\ format expression so
`eval(parse(text = ...))` can produce the object (working directory =
study root).

For package-backed studies, reads `inst/replication_code/*.R` from the
study package GitHub repo when the package is not installed (same idea
as reading `code/*.R` from the registry repo).

## Examples

``` r
if (FALSE) { # \dontrun{
head(get_code("10.1177/00491241211036161", "fig_1"))
get_code("10.1017/S0003055403000534", "tab_1", language = "stata")
get_code("rep-template", "tab_1", mode = "run")
} # }
```
