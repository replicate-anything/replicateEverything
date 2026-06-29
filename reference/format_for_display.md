# Apply an optional format function to an analysis object

When `replication.yml` defines `format`, the analysis object (typically
from `make_*`) is passed to `format_*` for display. Otherwise the object
is returned unchanged.

## Usage

``` r
format_for_display(
  object,
  doi,
  what,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- object:

  Analysis output to format.

- doi:

  Character. DOI of the paper.

- what:

  Replication identifier.

- install_deps:

  Logical. Install missing dependencies when `TRUE`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Object suitable for display (often an HTML string or ggplot).

## Examples

``` r
if (FALSE) { # \dontrun{
result <- render_replication("10.1177/00491241211036161", "fig_1")
format_for_display(replication_object(result), "10.1177/00491241211036161", "fig_1")
} # }
```
