# Collect upstream pointers from study / stub metadata

Prefers `paper.extends` (inheritance) and `paper.related` (explicit
citation of the original). Each entry is a list with optional `doi`,
`repo`, `handle`, `label`, and `source`.

## Usage

``` r
study_upstream_refs_from_meta(meta)
```

## Arguments

- meta:

  Parsed replication.yml or registry stub.

## Value

List of upstream reference lists.
