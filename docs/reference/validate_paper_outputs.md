# Validate all precomputed outputs for one paper

Validate all precomputed outputs for one paper

## Usage

``` r
validate_paper_outputs(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name.

## Value

Invisibly `TRUE` if every replication has an artifact.
