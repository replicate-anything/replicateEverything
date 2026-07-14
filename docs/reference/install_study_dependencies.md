# Install dependencies for one folder-backed or registry study

Maintainer setup only. Installs declared R CRAN packages, Python pip
packages, and runs study Stata install scripts (`install_stata_deps.do`)
once. Works for **folder-backed** and **package-backed** registry
studies. Does **not** build display outputs — use
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)
for that.

## Usage

``` r
install_study_dependencies(
  location,
  registry_root = NULL,
  repo = NULL,
  folder = NULL,
  from_registry_index = FALSE
)
```

## Arguments

- location:

  Study DOI, registry handle, local path, or GitHub slug.

- registry_root:

  Optional registry checkout for monorepo dev.

- repo, folder:

  Optional registry row hints.

- from_registry_index:

  Logical. When `TRUE` (set by
  [`install_registry_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_registry_dependencies.md)),
  never treat blank input or a sibling folder name in
  [`getwd()`](https://rdrr.io/r/base/getwd.html) as the local study.

## Value

Invisibly `TRUE` on success.

## Details

Live Run and Shiny probe dependencies only; call this function (or
[`install_registry_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_registry_dependencies.md))
when onboarding a machine.

## See also

[`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md),
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md),
[`install_registry_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_registry_dependencies.md)

## Examples

``` r
if (FALSE) { # \dontrun{
install_study_dependencies("10.1017/S0003055426101749")
install_study_dependencies("path/to/study-repo")
} # }
```
