# Copy the bundled Shiny app into a deploy directory

Materializes `inst/shiny` from an installed `replicateEverything` build
into `dest`, for Shiny Server and similar hosts that expect `app.R` (and
`www/`) in a fixed folder. Existing `local.R` in `dest` is never
overwritten.

## Usage

``` r
save_local_shiny(
  dest = getwd(),
  package = "replicateEverything",
  overwrite = TRUE,
  live_run = TRUE,
  feedback_enabled = TRUE,
  feedback_file = "data/feedback.csv"
)
```

## Arguments

- dest:

  Target directory. Defaults to the current working directory.

- package:

  Package that ships the app; default `"replicateEverything"`.

- overwrite:

  If `TRUE`, replace existing app files except `local.R`.

- live_run:

  If `TRUE` (default), deployed app shows Live Run controls; if `FALSE`,
  display-only deployment.

- feedback_enabled:

  If `TRUE` (default for server deploys), enable the in-app feedback
  form and CSV logging at `feedback_file`. Interactive
  [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
  leaves feedback off unless you set options yourself.

- feedback_file:

  Relative or absolute path for the feedback CSV (default
  `data/feedback.csv`, relative to the deploy directory).

## Value

Invisibly, normalized `dest`.

## Details

Deploy settings (`live_run`, feedback) are written to `deploy-options.R`
and baked into the top of the materialized `app.R`. No `local.R` is
required for those options.

## Examples

``` r
if (FALSE) { # \dontrun{
# After install_github("replicate-anything/replicateEverything"):
save_local_shiny("/srv/shiny/replicate", live_run = FALSE, feedback_enabled = TRUE)
save_local_shiny("/srv/shiny/replicate", live_run = TRUE) # feedback ON by default
} # }
```
