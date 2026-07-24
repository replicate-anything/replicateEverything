# Maintainer guidance when dependencies or executables are missing

Used in error messages, Shiny modals, and documentation. Returns plain
text suitable for [`stop()`](https://rdrr.io/r/base/stop.html) or
display.

## Usage

``` r
maintainer_dependency_hint(
  doi = NULL,
  audit = NULL,
  scope = c("study", "package"),
  package = NULL,
  missing_r = NULL,
  include_path_hints = TRUE
)
```

## Arguments

- doi:

  Optional study DOI for single-study install hints.

- audit:

  Optional `study_system_compatibility` object from
  [`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md).

- scope:

  `"study"` or `"package"` for package-backed studies.

- package:

  Package name when `scope = "package"`.

- missing_r:

  Character vector of missing CRAN packages.

- include_path_hints:

  Include `.Renviron` lines for Python/Stata.

## Value

Character scalar (multi-line).

## See also

[`install_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_dependencies.md),
[`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md)

## Examples

``` r
if (FALSE) { # \dontrun{
maintainer_dependency_hint("10.1017/S0003055426101749")
} # }
```
