# Safe lookup in a named Stata-globals character vector

R 4.5+ errors on `x[["missing"]]` for atomic vectors; treat missing
names as unresolved instead of aborting code-link checks.

## Usage

``` r
stata_global_lookup(globals, name)
```
