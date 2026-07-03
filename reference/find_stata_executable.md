# Locate a Stata executable

Checks `getOption("replicateEverything.stata_executable")` first, then
common install paths (Windows, Linux, macOS) and `PATH`.

## Usage

``` r
find_stata_executable()
```

## Value

Normalized path or `NULL`.
