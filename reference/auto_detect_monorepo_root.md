# Detect a local replicate-anything monorepo root

Looks for `registry/index.csv` next to the installed or loaded
replicateEverything package, the Shiny launch directory, or uses
`getOption("replicateEverything.study_folders_root")`.

## Usage

``` r
auto_detect_monorepo_root()
```

## Value

Normalized path or `NULL`.
