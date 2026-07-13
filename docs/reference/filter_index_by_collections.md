# Subset registry index rows by collection tag(s)

Registry `collections` are pipe-separated in `index.csv` (e.g.
`"World Bank|PED"`). A row is kept when any requested tag appears in
that row's tags.

## Usage

``` r
filter_index_by_collections(index, collections)
```

## Arguments

- index:

  Registry index data frame from
  [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md).

- collections:

  Character vector of collection tags (e.g. `"APSR"`).

## Value

Filtered index data frame.
