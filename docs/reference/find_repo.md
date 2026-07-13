# Find the repository for a paper replication

Looks up the replication registry to determine which repository contains
the replication materials for a given DOI.

## Usage

``` r
find_repo(doi)
```

## Arguments

- doi:

  Character. DOI of the paper.

## Value

Character string containing the GitHub repository name.

## Examples

``` r
if (FALSE) { # \dontrun{
find_repo("10.1177/00491241211036161")
} # }
```
