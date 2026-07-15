# Run the bundled Shiny demo app

Launches the demo from `inst/shiny` inside the installed package. Does
not auto-update `replicateEverything` from GitHub (the running session
already uses the installed package). Interactive defaults: Live Run
available; feedback form off. For server deploys with feedback on, use
[`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md).
A live instance is hosted at <https://shiny2.wzb.eu/ipi/replicate/>.

## Usage

``` r
run_shiny_app(...)
```

## Arguments

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

The value returned by
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Examples

``` r
if (FALSE) { # \dontrun{
run_shiny_app()
} # }
```
