# Normalize a DOI

Cleans and standardizes a DOI string so it can be used consistently
across package functions. The function removes common DOI URL prefixes
and trims whitespace.

## Usage

``` r
normalize_doi(doi)
```

## Arguments

- doi:

  Character. A DOI string or DOI URL.

## Value

A cleaned DOI string.

## Examples

``` r
normalize_doi("https://doi.org/10.1177/00491241211036161")
#> [1] "10.1177/00491241211036161"
```
