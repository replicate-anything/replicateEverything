# Detect a local registry checkout

Uses `getOption("replicateEverything.registry_root")` or a sibling
`registry/` folder in an auto-detected monorepo.

## Usage

``` r
auto_detect_registry_root()
```

## Value

Normalized path or `NULL`.
