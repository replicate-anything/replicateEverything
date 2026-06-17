# Fetch replication metadata for a paper

Fetch replication metadata for a paper

## Usage

``` r
get_replication_meta_impl(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Parsed `replication.yml` contents.
