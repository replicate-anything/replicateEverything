# Languages declared in replication.yml

Prefer top-level `languages:` or `paper.languages:`. When omitted,
infers from `engine:` on prep/replication entries.

## Usage

``` r
study_declared_languages(meta)
```

## Arguments

- meta:

  Parsed replication metadata.

## Value

Character vector of `r`, `stata`, and/or `python`.
