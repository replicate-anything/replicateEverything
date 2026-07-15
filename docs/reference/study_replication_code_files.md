# Code script paths declared in study replication metadata

Collects runner `code:` paths and optional `format:` scripts from every
step in `replication.yml` (unified `steps:` or legacy blocks).

## Usage

``` r
study_replication_code_files(meta)
```

## Arguments

- meta:

  Parsed replication metadata.

## Value

Character vector of study-relative code paths.
