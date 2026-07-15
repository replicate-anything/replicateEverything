# Parse DOI deep-link fields from a URL search string

Parse DOI deep-link fields from a URL search string

## Usage

``` r
parse_shiny_deep_link_from_search(url_search)
```

## Arguments

- url_search:

  Value of `session$clientData$url_search`.

## Value

List from
[`extract_shiny_deep_link()`](https://replicate-anything.github.io/replicateEverything/reference/extract_shiny_deep_link.md),
or `NULL`.
