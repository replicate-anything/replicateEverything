# Package version and build identity

`sha` / `bundled_sha` come from the bundled `inst/shiny/BUNDLE_SHA`
stamp (used for deploy matching). `remote_sha` records `RemoteSha` from
[`packageDescription()`](https://rdrr.io/r/utils/packageDescription.html)
when installed via GitHub (`remotes`, etc.).

## Usage

``` r
package_build_info(package = "replicateEverything")
```

## Arguments

- package:

  Package name.

## Value

List with `version`, `sha`, `bundled_sha`, `remote_sha`, and `source`.
