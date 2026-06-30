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
  overwrite = TRUE
)
```

## Arguments

- dest:

  Target directory. Defaults to the current working directory.

- package:

  Package that ships the app; default `"replicateEverything"`.

- overwrite:

  If `TRUE`, replace existing app files except `local.R`.

## Value

Invisibly, normalized `dest`.

## Examples

``` r
if (FALSE) { # \dontrun{
# After install_github("replicate-anything/replicateEverything"):
save_local_shiny("/srv/shiny/replicate")
} # }
```
