# Compare replicated GLM tables to published benchmarks

Checks coefficient estimates, standard errors, and sample sizes for a
vector of models against values taken from the published table. Intended
for study repos under `tests/substantive/<step_id>.R`.

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

## Examples

``` r
if (FALSE) { # \dontrun{
models <- run_replication("10.1017/S0003055403000534", "tab_1")
check_glm_table_benchmark(models, list(
  terms = c("warl", "warl", "warl", "empwarl", "cowwarl"),
  coef = c(-0.954, -0.849, -0.916, -0.688, -0.551),
  se = c(0.314, 0.388, 0.312, 0.264, 0.374),
  nobs = c(6327, 5186, 6327, 6360, 5378)
))
} # }
```
