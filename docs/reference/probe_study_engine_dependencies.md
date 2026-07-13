# Probe declared R / Python / Stata dependencies from yaml

Probe declared R / Python / Stata dependencies from yaml

## Usage

``` r
probe_study_engine_dependencies(meta, study_root = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- study_root:

  Local study or package source root (for Stata probes).

## Value

List with `languages`, `dependencies`, `ready`, `install_needed`.
