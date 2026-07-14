# Whether a location string looks like a DOI (not a GitHub org/repo slug)

DOIs such as `10.1017/S0003055426101622` match `org/repo` patterns but
must not be sent to GitHub clone helpers.

## Usage

``` r
looks_like_doi_location(x)
```

## Arguments

- x:

  Character scalar.

## Value

Logical scalar.
