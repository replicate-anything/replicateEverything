# Whether a parsed Stata global value is a usable literal path

Skips locals/macros such as `` "`root'" `` or `"\${maindir}/data/raw"`
that `init_study_paths.do` assigns at runtime.

## Usage

``` r
is_resolved_stata_global_value(val)
```
