# Ensure installed replicateEverything matches GitHub `main`

Used by the bundled Shiny app at startup. Compares installed `RemoteSha`
to the latest commit on `replicate-anything/replicateEverything` via
[`github_remote_sha()`](https://replicate-anything.github.io/replicateEverything/reference/github_remote_sha.md).
When outdated and auto-update is enabled, installs with
[`remotes::install_github()`](https://remotes.r-lib.org/reference/install_github.html)
and attempts a namespace reload. Network failures fail soft (status
`unknown`) without blocking app start.

## Usage

``` r
ensure_replicate_everything_current(
  package = "replicateEverything",
  repo = "replicate-anything/replicateEverything",
  ref = "main",
  install = TRUE
)
```

## Arguments

- package:

  Package name.

- repo:

  GitHub slug.

- ref:

  Git ref.

- install:

  If `FALSE`, only check (no install).

## Value

Named list status (also stored in
`options(replicate_shiny.auto_update_status)`).
