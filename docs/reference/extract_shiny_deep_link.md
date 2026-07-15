# Extract DOI deep-link fields from a parsed query list

Extract DOI deep-link fields from a parsed query list

## Usage

``` r
extract_shiny_deep_link(query_list)
```

## Arguments

- query_list:

  Named list from
  [`parse_shiny_query_string()`](https://replicate-anything.github.io/replicateEverything/reference/parse_shiny_query_string.md).

## Value

List with `doi`, `what`, `language`, or `NULL`.
