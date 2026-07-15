# Diagnose Shiny deployment and installed package identity

Use on the Shiny host (interactive R session) to confirm which
`replicateEverything` build is installed, where it lives on disk,
whether the deployed `app.R` bundle matches, and whether expected
functions exist in the loaded namespace.

## Usage

``` r
package_deploy_diagnostics(
  deploy_dir = NULL,
  package = "replicateEverything",
  print = TRUE
)
```

## Arguments

- deploy_dir:

  Deploy directory containing `app.R`. Defaults to
  [`shiny_deploy_dir()`](https://replicate-anything.github.io/replicateEverything/reference/shiny_deploy_dir.md).

- package:

  Package name; default `"replicateEverything"`.

- print:

  If `TRUE`, print a human-readable report to the console.

## Value

Named list (invisibly when `print = TRUE`).

## Examples

``` r
if (FALSE) { # \dontrun{
remotes::install_github("replicate-anything/replicateEverything")
replicateEverything::save_local_shiny("/srv/shiny/replicate")
replicateEverything::package_deploy_diagnostics("/srv/shiny/replicate")
} # }
```
