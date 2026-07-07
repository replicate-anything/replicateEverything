# List pipeline prep steps for a paper

Returns entries from the `prep:` block in `replication.yml`.

## Usage

``` r
list_prep_steps(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A list of prep step entries.
