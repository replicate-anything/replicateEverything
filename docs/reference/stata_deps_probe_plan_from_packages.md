# Build a Stata probe from `stata_packages:`, with exit-code attribution

Uses `which` (or `findfile` for file-only packages; see
[`stata_package_probe_spec()`](https://replicate-anything.github.io/replicateEverything/reference/stata_package_probe_spec.md))
plus `help` (and reghdfe runtime checks when needed). Each check exits
with a distinct code so a failing probe run can be attributed back to
the exact package that failed, instead of blaming every declared package
(see
[`stata_dependencies_satisfied()`](https://replicate-anything.github.io/replicateEverything/reference/stata_dependencies_satisfied.md)).

## Usage

``` r
stata_deps_probe_plan_from_packages(packages)
```

## Arguments

- packages:

  Character vector of ado command names.

## Value

List with `lines` (character vector of Stata commands) and `code_map`
(named character vector: exit code as name, package name as value).
