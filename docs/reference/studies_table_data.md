# Filter / sort studies from the precomputed Shiny cache

Trivial collection filter only — no yaml fetch.

## Usage

``` r
studies_table_data(cache, collection = NULL)
```

## Arguments

- cache:

  Result of
  [`load_shiny_studies_cache()`](https://replicate-anything.github.io/replicateEverything/reference/load_shiny_studies_cache.md)
  or
  [`build_shiny_studies_cache()`](https://replicate-anything.github.io/replicateEverything/reference/build_shiny_studies_cache.md).

- collection:

  Optional collection tag, or `NULL` / empty / `"__all_studies__"` for
  all.

## Value

List of study records.

## Examples

``` r
if (FALSE) { # \dontrun{
rows <- studies_table_data(load_shiny_studies_cache(), collection = "APSR")
} # }
```
