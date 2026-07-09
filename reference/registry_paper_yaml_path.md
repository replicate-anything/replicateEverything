# Path to a registry paper stub yaml file

Prefers `papers/<folder>.yml`; falls back to legacy
`papers/<folder>/replication.yml` when present.

## Usage

``` r
registry_paper_yaml_path(registry_root, folder)
```

## Arguments

- registry_root:

  Registry checkout root.

- folder:

  Registry folder name.

## Value

Character path (flat layout path even when missing).
