# Resolve all paper.source_repository credits

Canonical field is `paper.source_repository`: one URL (preferred) or a
yaml list of URLs / short credits for original materials deposits.
Legacy aliases `source_url` and `source_repo` are accepted when the
canonical field is empty. When multiple sources are declared, the first
is treated as primary (see
[`paper_source_repository()`](https://replicate-anything.github.io/replicateEverything/reference/paper_source_repository.md)).

## Usage

``` r
paper_source_repositories(paper = NULL, meta = NULL)
```

## Arguments

- paper:

  Optional `paper` list from `replication.yml` or a registry stub.

- meta:

  Optional full parsed metadata (uses `meta$paper`).

## Value

Character vector (possibly empty).
