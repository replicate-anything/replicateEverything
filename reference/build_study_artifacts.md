# Build display artifacts for a folder-backed study

Runs every registered table and figure, saves formatted outputs under
`artifacts/`, and writes `artifacts/manifest.json`. Intended to be run
from the study repository root (or pass the path explicitly).

## Usage

``` r
build_study_artifacts(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL
)
```

## Arguments

- location:

  Local study path or GitHub address. Defaults to `"."` when the working
  directory contains `replication.yml`.

- install_deps:

  Logical. Install missing CRAN dependencies when `TRUE`.

- ids:

  Optional character vector of replication ids to build. When `NULL`,
  builds every figure and table in `replication.yml`.

- registry_root:

  Optional registry checkout path for monorepo dev.

## Value

Invisibly, a list with `artifact_dir`, `manifest`, and per-id status.

## Details

Registry papers use `registry/scripts/build_artifacts.R` instead;
folder-backed studies keep materials in their own repository.

## Examples

``` r
if (FALSE) { # \dontrun{
build_study_artifacts(".", install_deps = TRUE)
} # }
```
