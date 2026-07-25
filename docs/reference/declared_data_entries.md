# Declared remote data entries from study metadata

Reads `dataverse.files` (and optional top-level `data_files:`) from
study yaml. Each entry maps a local study-relative `path` to a remote
location via `url`, or Dataverse `id` / `file_id` (optional
`original: true` for native uploads behind `.tab` listings).

## Usage

``` r
declared_data_entries(meta)
```

## Arguments

- meta:

  Parsed replication metadata (full study yaml).

## Value

List of named lists with at least `path`.

## Details

This is **location wiring**, not a DAG step: raw inputs land under
`data/`; transform steps consume them after materialize.
