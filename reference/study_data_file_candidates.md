# Candidate paths for a replication data file

Checks (1) the study checkout at `study_root/<rel_path>`, (2) a sibling
monorepo study repo when configured, then (3) deployed Shiny data at
`<study_data_root>/data/<study_folder>/<basename>`.

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
