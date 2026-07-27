# Root directory for external study data

Uses `ctx$study_data_root`, then
`getOption("replicateEverything.study_data_root")`, then
`getOption("replicateEverything.study_folders_root")` (monorepo), then
[`getwd()`](https://rdrr.io/r/base/getwd.html) (Shiny app directory on
server).

## Usage

``` r
study_data_root(ctx = NULL)
```

## Arguments

- ctx:

  Optional paper context.

## Value

Normalized path.

## Details

Large files resolve under `<root>/data/<study_folder>/`.
