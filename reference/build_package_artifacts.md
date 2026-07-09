# Build display artifacts for a package-backed study

Runs pipeline prep steps from the package `replication.yml`, then builds
every registered table and figure into `inst/report/artifacts/` (or
`output_dir` when set). Study packages can delegate from
`build_report()`.

## Usage

``` r
build_package_artifacts(
  package,
  install_deps = TRUE,
  ids = NULL,
  output_dir = NULL,
  force_prep = FALSE
)
```

## Arguments

- package:

  Character name of the installed study package.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`.

- ids:

  Optional character vector of replication ids to build.

- output_dir:

  Optional output directory. Defaults to `inst/report/artifacts/` under
  the package source tree.

- force_prep:

  Logical. Re-run prep steps even when outputs already exist.

## Value

Invisibly, a list with `artifact_dir`, `manifest`, and `manifest_path`.

## Examples

``` r
if (FALSE) { # \dontrun{
build_package_artifacts("rep1371journalpone0278337", install_deps = TRUE)
} # }
```
