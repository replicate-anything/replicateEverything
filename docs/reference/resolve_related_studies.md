# Resolve related keys to display records (title / repo / href)

Shared by Shiny Related column and `summary.replicate_study`.

## Usage

``` r
resolve_related_studies(
  keys,
  direction = c("upstream", "downstream"),
  index = NULL
)
```

## Arguments

- keys:

  Character vector of DOI/handle keys.

- direction:

  `"upstream"` or `"downstream"` (for labels).

- index:

  Optional registry index (defaults to
  [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)).

## Value

List of lists with `key`, `title`, `repo`, `doi`, `in_registry`, `href`,
`label`.
