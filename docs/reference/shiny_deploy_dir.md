# Shiny deploy directory (app bundle root)

Prefers `options(replicate_shiny.app_dir)`, then `SHINY_APP_DIR`, then
[`getwd()`](https://rdrr.io/r/base/getwd.html). Relative feedback paths
and `local.R` resolve here.

## Usage

``` r
shiny_deploy_dir()
```

## Value

Normalized path.
