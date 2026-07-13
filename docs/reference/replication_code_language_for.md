# Code language for a replication (for Shiny syntax highlighting)

Code language for a replication (for Shiny syntax highlighting)

## Usage

``` r
replication_code_language_for(
  doi,
  what,
  language = NULL,
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

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

`"stata"` or `"r"`.
