# Whether a top-level assignment RHS is a safe script constant

Constants (e.g. `TAB_3_TREATMENT_TERMS <- c(...)`) must be evaluated
into `env` so helper functions defined in the same file can resolve
them. Data-loading or side-effect calls are skipped.

## Usage

``` r
is_safe_script_constant_rhs(rhs)
```
