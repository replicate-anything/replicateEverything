# Format an error when a study data file cannot be located

Format an error when a study data file cannot be located

## Usage

``` r
study_data_not_found_message(rel_path, study_root, checked, meta, ctx = NULL)
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
