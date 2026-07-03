# Ensure replication data files exist under a study root

Looks in the study checkout, then `data/<study>/<file>` under the
working directory. When found externally, links or copies into
`study_root` so Stata paths keep working.

## Usage

``` r
ensure_study_data_files(data_files, study_root, meta, ctx = NULL)
```

## Arguments

- data_files:

  Character vector of paths relative to study root.

- study_root:

  Normalized study repository root.

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

## Value

Invisibly, character vector of resolved paths under `study_root`.
