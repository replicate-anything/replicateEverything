# Extract study deep-link key from a parsed query list

Query contract (path prefix such as `/ipi/replicate/` is irrelevant;
only the search string matters):

- `doi` — study DOI (preferred), or

- `handle` — registry handle / study key when there is no DOI

Legacy `what` / `language` query params are ignored if present.

## Usage

``` r
extract_shiny_deep_link(query_list)
```

## Arguments

- query_list:

  Named list from
  [`parse_shiny_query_string()`](https://replicate-anything.github.io/replicateEverything/reference/parse_shiny_query_string.md).

## Value

List with `doi` (study key: DOI or handle), or `NULL`.
