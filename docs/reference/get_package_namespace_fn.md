# Resolve a function from an installed package namespace

Checks exported and internal bindings. When the namespace version
differs from the on-disk package version, stops with a restart hint
(typical when Shiny workers were not restarted after
`install_github()`).

## Usage

``` r
get_package_namespace_fn(
  name,
  package = "replicateEverything",
  aliases = character(0)
)
```

## Arguments

- name:

  Function name.

- package:

  Package name.

- aliases:

  Optional alternate names to try.

## Value

The resolved function.
