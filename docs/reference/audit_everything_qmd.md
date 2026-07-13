# Path to the registry Quarto audit report

Returns `audit_everything.qmd` from a local registry checkout. Looks in
`registry_root`, `getOption("replicateEverything.registry_root")`,
[`auto_detect_registry_root()`](https://replicate-anything.github.io/replicateEverything/reference/auto_detect_registry_root.md),
or a sibling `registry/` folder in a monorepo.

## Usage

``` r
audit_everything_qmd(registry_root = NULL)
```

## Arguments

- registry_root:

  Optional path to the registry repository root.

## Value

Character path, or `""` if not found.
