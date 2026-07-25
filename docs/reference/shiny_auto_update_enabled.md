# Whether Shiny may auto-update replicateEverything from GitHub

Reads `options(replicate_shiny.auto_update_replicate_everything)` or the
alias `options(replicateEverything.shiny_auto_update)`. Default `TRUE`
(production Shiny hosts). Set either option to `FALSE` for local
[`pkgload::load_all`](https://pkgload.r-lib.org/reference/load_all.html)
/ monorepo development.
[`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
forces the option off.

## Usage

``` r
shiny_auto_update_enabled()
```

## Value

Logical scalar.
