# Path to a registry study stub yaml file

Prefers `studies/<folder>.yml`; falls back to legacy `papers/` layouts
when present.

## Usage

``` r
registry_paper_yaml_path(registry_root, folder)

registry_study_yaml_path(registry_root, folder)
```

## Arguments

- registry_root:

  Registry checkout root.

- folder:

  Registry folder name.

## Value

Character path (flat layout path under `studies/` when missing).
