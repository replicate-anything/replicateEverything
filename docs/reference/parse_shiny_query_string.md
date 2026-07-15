# Parse a Shiny URL query string

Accepts values from `session$clientData$url_search` or
`window.location.search`. Leading `?` is optional.

## Usage

``` r
parse_shiny_query_string(query_string)
```

## Arguments

- query_string:

  Character scalar, e.g. `"?doi=10.1017/..."`.

## Value

Named character list suitable for deep-link handling; empty when absent.
