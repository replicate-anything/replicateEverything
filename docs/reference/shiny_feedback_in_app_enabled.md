# Whether the in-app Shiny feedback form (text box + submit) is enabled

Prefers `options(replicate_shiny.feedback_in_app_enabled)`. When that
option is unset, follows `replicate_shiny.feedback_enabled` (set by
[`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
/ `deploy-options.R`). Interactive
[`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
defaults leave both unset/FALSE so the form stays off.

## Usage

``` r
shiny_feedback_in_app_enabled()
```

## Value

Logical scalar.
