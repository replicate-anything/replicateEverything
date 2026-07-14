# Build display outputs for a package-backed study

Runs pipeline prep steps from `replication.yml` when present, then every
registered table and figure, and writes formatted outputs plus
`manifest.json`. Works for folder-backed studies (`outputs/`) and
package-backed studies (`inst/report/outputs/` or
`inst/report/artifacts/`).

## Usage

``` r
build_package_artifacts(
  package,
  install_deps = TRUE,
  ids = NULL,
  output_dir = NULL,
  force_prep = FALSE,
  only_missing = FALSE
)

build_study_artifacts(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL,
  force_prep = FALSE,
  only_missing = FALSE
)

build_study_outputs(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL,
  output_dir = NULL,
  force_prep = FALSE,
  only_missing = FALSE
)
```

## Arguments

- package:

  Character name of the installed study package.

- install_deps:

  Logical. Install missing CRAN, pip, and Stata dependencies when
  `TRUE`.

- ids:

  Optional character vector of replication ids to build. When `NULL`,
  builds every figure and table in `replication.yml`.

- output_dir:

  Optional output directory (package studies only). Defaults to the
  package report outputs directory.

- force_prep:

  Logical. Re-run prep steps even when outputs already exist.

- only_missing:

  Logical. When `TRUE`, skip replications whose artifacts already exist
  (see
  [`artifact_available()`](https://replicate-anything.github.io/replicateEverything/reference/artifact_available.md)).

- location:

  Local study path, GitHub address, or installed package name. Defaults
  to `"."` when the working directory contains `replication.yml` or
  `DESCRIPTION`.

- registry_root:

  Optional registry checkout path for monorepo dev (folder studies
  only).

## Value

Invisibly, a list with `artifact_dir`, `manifest`, and `manifest_path`.

Invisibly, a list with `artifact_dir`, `manifest`, and per-id status.

Invisibly, a list with `output_dir`, `manifest`, and per-id status.

## Functions

- `build_package_artifacts()`: Package-backed implementation.

  Runs pipeline prep steps from the package `replication.yml`, then
  builds every registered table and figure into `inst/report/artifacts/`
  (or `output_dir` when set). Study packages can delegate from
  `build_report()`.

- `build_study_artifacts()`: Folder-backed implementation.

  Runs pipeline prep steps from `replication.yml` when present, then
  every registered table and figure, saves formatted outputs under
  `outputs/`, and writes `outputs/manifest.json`. Intended to be run
  from the study repository root (or pass the path explicitly).

  Registry papers use `registry/scripts/build_artifacts.R` instead;
  folder-backed studies keep materials in their own repository.

## See also

[`build_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_outputs.md)
for registry-wide or DOI-scoped builds.

## Examples

``` r
if (FALSE) { # \dontrun{
build_study_outputs(".", install_deps = TRUE)
build_study_outputs("rep1371journalpone0278337", install_deps = TRUE)
build_study_outputs(".", only_missing = TRUE)
} # }
```
