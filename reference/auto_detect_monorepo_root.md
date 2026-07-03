# Detect a local replicate-anything monorepo root

Looks for `registry/index.csv` next to the installed or loaded
replicateEverything package, or uses
`getOption("replicateEverything.study_folders_root")`.

## Usage

``` r
auto_detect_monorepo_root()
```

## Value

Normalized path or `NULL`.
