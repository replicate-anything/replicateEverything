# Merge default Stata globals with any parsed or cached values

Shiny reactive state can strip names from character vectors; treat
unnamed or empty globals as missing and fall back to
[`default_stata_globals()`](https://replicate-anything.github.io/replicateEverything/reference/default_stata_globals.md).

## Usage

``` r
normalize_stata_globals(study_root, globals = NULL)
```
