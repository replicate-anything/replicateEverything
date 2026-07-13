# Validate all artifacts for a paper

Validate all artifacts for a paper

## Usage

``` r
validate_paper_artifacts(doi, repo = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug.

## Value

Invisibly `TRUE` if every replication has an artifact.

## Examples

``` r
if (FALSE) { # \dontrun{
validate_paper_artifacts("10.1177/00491241211036161")
} # }
```
