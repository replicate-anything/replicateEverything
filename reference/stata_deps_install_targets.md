# Resolve Stata install scripts or generated install from `stata_packages:`

Resolve Stata install scripts or generated install from
`stata_packages:`

## Usage

``` r
stata_deps_install_targets(
  study_root,
  staging_dir = NULL,
  meta = NULL,
  rep = NULL
)
```

## Arguments

- study_root:

  Local study repository root.

- staging_dir:

  Optional staging directory for generated runner files.

- meta:

  Optional parsed replication metadata.

- rep:

  Optional replication entry.

## Value

List with `scripts`, `generated`, and optional `run_dir`.
