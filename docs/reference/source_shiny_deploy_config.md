# Source deploy-options.R and local.R from a Shiny deploy directory

Order: `deploy-options.R` (base settings from
[`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)),
then `local.R` (server overrides; never overwritten on deploy).

## Usage

``` r
source_shiny_deploy_config(dir)
```

## Arguments

- dir:

  Deploy directory containing `app.R`.

## Value

Invisibly, `TRUE` when `dir` exists.
