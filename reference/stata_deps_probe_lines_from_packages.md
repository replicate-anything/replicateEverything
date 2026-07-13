# Build a Stata probe from `stata_packages:`

Uses `which` plus `help` (and reghdfe runtime checks when needed).

## Usage

``` r
stata_deps_probe_lines_from_packages(packages)
```

## Arguments

- packages:

  Character vector of ado command names.

## Value

Character vector of Stata commands.
