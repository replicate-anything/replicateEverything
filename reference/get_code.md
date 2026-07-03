# Retrieve replication code for a paper

Returns a single script suitable for the Code tab in Shiny. For Stata
replications, the substantive analysis from `stata_source` is inlined
after a short setup section so the script can be copied and run. R
replications return the analysis script only; optional `format_*`
helpers in separate files are labeled and omitted for Stata.

## Usage

``` r
get_code(doi, what, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (e.g., `"fig_1"`).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A character vector containing the lines of the replication script(s).

## Details

For package-backed studies, reads `inst/replication_code/*.R` from the
study package GitHub repo when the package is not installed (same idea
as reading `code/*.R` from the registry repo).

## Examples

``` r
if (FALSE) { # \dontrun{
head(get_code("10.1177/00491241211036161", "fig_1"))
} # }
```
