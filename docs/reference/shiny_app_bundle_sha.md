# SHA stamp for the running Shiny app bundle

Prefers `BUNDLE_SHA` next to the deployed `app.R`, then the bundled
stamp shipped inside the installed package.

## Usage

``` r
shiny_app_bundle_sha(package = "replicateEverything")
```

## Arguments

- package:

  Package that ships the Shiny app.

## Value

Seven-character SHA or `NA_character_`.
