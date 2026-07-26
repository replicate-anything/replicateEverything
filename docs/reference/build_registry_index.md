# Compile registry index.csv from study stub yaml files

Reads every `studies/*.yml` under a registry checkout and writes
`index.csv` with `collections`, `maintainer_*`, `languages`, and related
study columns. Upstream links come from stub `paper.related` /
`paper.extends`; `related_downstream` is inferred by reversing those
pointers across the registry. Also writes
[`build_shiny_studies_cache()`](https://replicate-anything.github.io/replicateEverything/reference/build_shiny_studies_cache.md)
→ `shiny_studies.json` for the Shiny Studies tab (no live yaml at list
time).

## Usage

``` r
build_registry_index(registry_root = NULL)
```

## Arguments

- registry_root:

  Path to the registry repository. Defaults to
  `getOption("replicateEverything.registry_root")` or
  [`auto_detect_registry_root()`](https://replicate-anything.github.io/replicateEverything/reference/auto_detect_registry_root.md).

## Value

Invisibly, a list with `index_path`, `index`, `n`, and
`shiny_studies_path`.

## Examples

``` r
if (FALSE) { # \dontrun{
build_registry_index("../registry")
} # }
```
