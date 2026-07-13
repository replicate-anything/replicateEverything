# Resolve the registry folder name for a paper

Uses the registry index `folder` column when available, otherwise
derives a path from the normalized DOI.

## Usage

``` r
resolve_paper_path(doi)
```

## Arguments

- doi:

  Character. DOI of the paper.

## Value

Character folder name under `studies/`.
