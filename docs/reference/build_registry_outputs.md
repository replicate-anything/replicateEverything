# Build precomputed outputs for every study in a registry checkout

Build precomputed outputs for every study in a registry checkout

## Usage

``` r
build_registry_outputs(
  registry_root = NULL,
  folders = NULL,
  only_missing = FALSE,
  install_deps = TRUE,
  force_prep = FALSE
)
```

## Arguments

- registry_root:

  Path to the registry repository.

- folders:

  Optional character vector of study folder names.

- only_missing:

  Logical. When `TRUE`, skip when the artifact already exists.

- install_deps:

  Logical. Install missing dependencies when `TRUE`.

- force_prep:

  Logical. Re-run prep steps even when outputs already exist.

## Value

Invisibly `TRUE` if every build succeeds.
