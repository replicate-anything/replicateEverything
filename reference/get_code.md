# Retrieve replication code for a paper

Returns the analysis script and, when defined, the format script.

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
