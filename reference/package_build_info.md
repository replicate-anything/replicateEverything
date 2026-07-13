# Package version and build identity

Uses `RemoteSha` from
[`packageDescription()`](https://rdrr.io/r/utils/packageDescription.html)
when installed via
[`remotes::install_github()`](https://remotes.r-lib.org/reference/install_github.html),
otherwise the bundled `inst/shiny/BUNDLE_SHA` stamp.

## Usage

``` r
package_build_info(package = "replicateEverything")
```

## Arguments

- package:

  Package name.

## Value

List with `version`, `sha`, and `source`.
