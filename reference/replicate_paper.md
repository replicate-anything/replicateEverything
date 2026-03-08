# Replicate all results from a paper

Runs all registered replications (figures and tables) for a given paper.

## Usage

``` r
replicate_paper(doi)
```

## Arguments

- doi:

  Character. DOI of the paper.

## Details

The function retrieves replication metadata from the registry, downloads
required data and scripts, and executes each replication sequentially.

## Examples

``` r
if (FALSE) { # \dontrun{
replicate_paper("10.1177/00491241211036161")
} # }
```
