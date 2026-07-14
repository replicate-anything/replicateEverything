# Resolve a local study root from a registry folder name

Reads the registry stub (or index row) for `loc` and resolves
`paper.study_folder` / repo slug siblings under the monorepo.

## Usage

``` r
try_resolve_study_from_registry_folder(loc)
```

## Arguments

- loc:

  Registry folder name such as `10.5555_cahw`.

## Value

Normalized study path or `NULL`.
