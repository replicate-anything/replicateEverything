# Compare replicated GLM tables to published benchmarks

Checks coefficient estimates, standard errors, and sample sizes for a
vector of models against values taken from the published table.
Available as `check_glm_table_benchmark()` when substantive check
scripts are sourced via
[`load_substantive_check_fn()`](https://replicate-anything.github.io/replicateEverything/reference/load_substantive_check_fn.md).

## Usage

``` r
check_glm_table_benchmark(models, spec, tolerance = 0.001)
```

## Arguments

- models:

  A list of fitted `glm` objects (one per table column).

- spec:

  Benchmark specification with character vector `terms` and numeric
  vectors `coef`, `se`, and `nobs` (same length).

- tolerance:

  Maximum absolute difference allowed for coefficients and standard
  errors (default `0.001`, matching three decimal places).

## Value

Invisibly `TRUE` on success.
