# Fetch `replication.yml` from a study package GitHub repo

Lets the app list tables/figures without installing the package.

## Usage

``` r
fetch_package_replication_yaml(meta, ctx)
```

## Arguments

- meta:

  Parsed registry stub or package metadata.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

Parsed yaml list or `NULL`.
