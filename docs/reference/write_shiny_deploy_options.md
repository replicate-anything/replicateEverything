# Write deploy-options.R for a Shiny deploy directory

Sets `options(replicate_shiny.live_run = ...)` and feedback options when
the deployed `app.R` starts (always overwritten on deploy, like
`BUNDLE_SHA`). Does **not** require `local.R`; if present, `local.R` is
sourced afterward and may override.

## Usage

``` r
write_shiny_deploy_options(
  dest,
  live_run = TRUE,
  feedback_enabled = TRUE,
  feedback_file = SHINY_FEEDBACK_DEFAULT_FILE,
  package = "replicateEverything"
)
```

## Arguments

- dest:

  Deploy directory.

- live_run:

  If `TRUE`, enable Live Run; if `FALSE`, display-only.

- feedback_enabled:

  If `TRUE`, enable in-app feedback form and server-side CSV logging.

- feedback_file:

  Relative or absolute feedback CSV path.

## Value

Invisibly, a list with `live_run`, `feedback_enabled`, and
`feedback_file`.
