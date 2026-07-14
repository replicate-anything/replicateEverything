# Validate precomputed outputs for every study in a registry checkout

Validate precomputed outputs for every study in a registry checkout

## Usage

``` r
validate_registry_outputs(registry_root = NULL, folders = NULL)
```

## Arguments

- registry_root:

  Path to the registry repository.

- folders:

  Optional character vector of study folder names.

## Value

Invisibly `TRUE` if every study passes.
