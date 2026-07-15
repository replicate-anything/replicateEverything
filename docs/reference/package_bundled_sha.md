# Bundled Shiny build stamp from an installed package

Reads `inst/shiny/BUNDLE_SHA` from the installed package. This is the
canonical identity for matching a deployed app bundle to a package
build.

## Usage

``` r
package_bundled_sha(package = "replicateEverything")
```

## Arguments

- package:

  Package name.

## Value

Seven-character SHA or `NA_character_`.
