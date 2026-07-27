# Resolve paper.source_repository (with legacy aliases)

Canonical field is `paper.source_repository`: URL (preferred) or short
text credit for the original data / materials deposit. Legacy aliases
`source_url` and `source_repo` are accepted when the canonical field is
empty.

## Usage

``` r
paper_source_repository(paper = NULL, meta = NULL)
```

## Arguments

- paper:

  Optional `paper` list from `replication.yml` or a registry stub.

- meta:

  Optional full parsed metadata (uses `meta$paper`).

## Value

Character scalar, or `NULL` when unset.
