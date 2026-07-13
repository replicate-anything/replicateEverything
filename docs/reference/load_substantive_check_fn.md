# Load a study substantive-check function, if defined

Looks for `tests/substantive/<what>.R` defining
`substantive_check_<what>()` or `substantive_check()`.

## Usage

``` r
load_substantive_check_fn(study_root, what)
```
