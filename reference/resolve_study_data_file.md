# Resolve a study data file on disk

Resolve a study data file on disk

## Usage

``` r
resolve_study_data_file(rel_path, study_root, meta, ctx = NULL)
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

List with `found`, `path`, and `checked`.
