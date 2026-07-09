# Locate a Stata executable

Checks `STATA` / `REPLICATE_STATA_EXECUTABLE` environment variables (set
in `~/.Renviron`), then
`getOption("replicateEverything.stata_executable")`, then common install
paths (Windows, Linux, macOS) and `PATH`.

## Usage

``` r
find_stata_executable()
```

## Value

Normalized path or `NULL`.
