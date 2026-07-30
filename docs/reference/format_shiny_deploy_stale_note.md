# Brief footer note when deploy stamp disagrees with the running package

Used by the Shiny footer instead of a top-of-page warning banner.
Returns `NULL` when there is nothing to report.

## Usage

``` r
format_shiny_deploy_stale_note(
  version_stale = FALSE,
  deploy_version = "",
  installed_version = "",
  deploy_lib_stale = FALSE,
  namespace_stale = FALSE
)
```

## Arguments

- version_stale:

  Logical; deploy stamp version differs from installed.

- deploy_version:

  Version string recorded in `deploy-options.R`.

- installed_version:

  Currently installed package version.

- deploy_lib_stale:

  Logical; deploy library path differs from loaded.

- namespace_stale:

  Logical; loaded namespace version differs from disk.

## Value

Character scalar note, or `NULL`.
