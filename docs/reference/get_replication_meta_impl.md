# Fetch replication metadata for a paper (uncached)

Implementation used by
[`get_replication_meta()`](https://replicate-anything.github.io/replicateEverything/reference/get_replication_meta.md).
Prefer the memoized wrapper in call sites.

## Usage

``` r
get_replication_meta_impl(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper (or study handle / local path accepted by
  [`prepare_doi_for_replication()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_doi_for_replication.md)).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Parsed `replication.yml` contents.
