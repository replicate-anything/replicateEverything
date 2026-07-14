# Write deploy-options.R for a Shiny deploy directory

Sets `options(replicate_shiny.live_run = ...)` when the deployed `app.R`
starts (always overwritten on deploy, like `BUNDLE_SHA`).

## Usage

``` r
write_shiny_deploy_options(dest, live_run = TRUE)
```

## Arguments

- dest:

  Deploy directory.

- live_run:

  If `TRUE`, enable Live Run; if `FALSE`, display-only.

## Value

Invisibly, `live_run`.
