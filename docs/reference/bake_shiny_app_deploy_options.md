# Bake live_run / feedback options into a materialized app.R

Replaces the `BAKED_DEPLOY_OPTIONS_*` marker block so deploy settings
are present even if `deploy-options.R` is missing. Does not require
`local.R`.

## Usage

``` r
bake_shiny_app_deploy_options(
  app_path,
  live_run = TRUE,
  feedback_enabled = TRUE,
  feedback_file = SHINY_FEEDBACK_DEFAULT_FILE
)
```

## Arguments

- app_path:

  Path to the deployed `app.R`.

- live_run:

  If `TRUE`, enable Live Run; if `FALSE`, display-only.

- feedback_enabled:

  If `TRUE`, enable in-app feedback form and server-side CSV logging.

- feedback_file:

  Relative or absolute feedback CSV path.

## Value

Invisibly, `app_path`.
