# Writable staging directory for Stata output

Uses `<study>/artifacts/staging` when the study folder is writable;
otherwise falls back to `<study_data_root>/staging/<study>` (Shiny
server).

## Usage

``` r
writable_stata_staging_dir(meta, ctx = NULL, study_root = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

- study_root:

  Optional local study repository root.

## Value

Normalized path.
