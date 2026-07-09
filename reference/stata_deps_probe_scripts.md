# Resolve optional Stata dependency probe script paths from study metadata

Studies may declare `stata_deps_probe: code/helpers/probe_stata_deps.do`
in `replication.yml`. The probe must exit 0 when dependencies are
satisfied and non-zero otherwise (check only — no network install).

## Usage

``` r
stata_deps_probe_scripts(study_root, meta = NULL)
```

## Arguments

- study_root:

  Local study repository root.

- meta:

  Optional parsed replication metadata.

## Value

Character vector of absolute paths to probe `.do` files.
