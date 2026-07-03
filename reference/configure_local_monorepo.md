# Configure options for a local replicate-anything monorepo

Sets `replicateEverything.registry_root`,
`replicateEverything.study_folders_root`, and enables sibling study
discovery. Call once per session when developing unpublished studies
locally.

## Usage

``` r
configure_local_monorepo(root = NULL)
```

## Arguments

- root:

  Monorepo root containing `registry/` and `rep-*` study folders. When
  `NULL`, attempts
  [`auto_detect_monorepo_root()`](https://replicate-anything.github.io/replicateEverything/reference/auto_detect_monorepo_root.md).

## Value

Invisibly, the monorepo root path.
