# Make R get_code lines runnable under eval(parse()) via yaml recipe

Always appends the yaml-implied execute recipe. Does not rely on
optional [`sys.nframe()`](https://rdrr.io/r/base/sys.parent.html)
footers (left gated if present).

## Usage

``` r
prepare_get_code_for_run(lines, rep)
```
