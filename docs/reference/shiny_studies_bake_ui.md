# Bake selectInput / collection filter payloads for Shiny startup

Studies must already be sorted in display order. Returns list columns of
`value`/`label` pairs so Shiny can call `updateSelectInput` without
re-sorting or rebuilding labels at session start.

## Usage

``` r
shiny_studies_bake_ui(studies)
```

## Arguments

- studies:

  List of study records from
  [`build_shiny_studies_cache()`](https://replicate-anything.github.io/replicateEverything/reference/build_shiny_studies_cache.md).

## Value

List with `select_choices` and `collection_choices`.
