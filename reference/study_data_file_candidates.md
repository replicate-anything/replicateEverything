# Candidate paths for a replication data file

Checks the study checkout, then `<root>/data/<study>/<file>`.

## Usage

``` r
study_data_file_candidates(rel_path, study_root, meta, ctx = NULL)
```

## Arguments

- rel_path:

  Path relative to study root (e.g. `data/file.dta`).

- study_root:

  Normalized study repository root.

- meta:

  Parsed replication metadata.

- ctx:

  Optional paper context.

## Value

Character vector of paths checked.
