# Build display outputs for a study repository

Runs pipeline prep steps from `replication.yml` when present, then every
registered table and figure, and writes formatted outputs plus
`manifest.json`. Works for folder-backed studies (`outputs/`) and
package-backed studies (`inst/report/outputs/` or
`inst/report/artifacts/`).

## Usage

``` r
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

- location:

  Local study path, GitHub address, or installed package name. Defaults
  to `"."` when the working directory contains `replication.yml` or
  `DESCRIPTION` — the same study that `doi = "local"` resolves to for
  [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
  /
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  /
  [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md).

- install_deps:

  Logical. Install missing CRAN, pip, and Stata dependencies when
  `TRUE`.

- ids:

  Optional character vector of replication ids to build. When `NULL`,
  builds every figure and table in `replication.yml`.

- registry_root:

  Optional registry checkout path for monorepo dev (folder studies
  only).

- output_dir:

  Optional output directory (package studies only). Defaults to the
  package report outputs directory.

- force_prep:

  Logical. Re-run prep steps even when outputs already exist.

- only_missing:

  Logical. When `TRUE`, skip replications whose artifacts already exist
  (see
  [`artifact_available()`](https://replicate-anything.github.io/replicateEverything/reference/artifact_available.md)).

## Value

Invisibly, a list with `output_dir`, `manifest`, and per-id status.

## See also

[`build_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_outputs.md)
for registry-wide or DOI-scoped builds.

## Examples

``` r
if (FALSE) { # \dontrun{
# setwd() to the study repo (or open its RStudio project), then:
setwd("path/to/rep-my-study")
list_replications("local")  # sanity-check before baking
build_study_outputs(".", install_deps = TRUE)
build_study_outputs("rep1371journalpone0278337", install_deps = TRUE)
build_study_outputs(".", only_missing = TRUE)
} # }
```
