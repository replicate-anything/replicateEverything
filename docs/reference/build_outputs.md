# Build precomputed outputs

Maintainer helper: runs registered table and figure replications and
writes formatted outputs to disk (folder-backed studies: study repo
`outputs/`; package-backed: installed package report outputs). Mirrors
[`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md)
dispatch for registry-wide or single-study builds.

## Usage

``` r
build_outputs(
  doi = NULL,
  what = NULL,
  location = NULL,
  registry_root = NULL,
  folders = NULL,
  repo = NULL,
  folder = NULL,
  language = NULL,
  install_deps = TRUE,
  only_missing = FALSE,
  force_prep = FALSE
)
```

## Arguments

- doi:

  Character DOI, or `"everywhere"` to build every registry study that is
  cloned locally in the monorepo (skips and lists studies without a
  local checkout). Ignored when `location` is set.

- what:

  Replication id, or `"everything"` (default when `doi` or `location` is
  set) to build every table and figure in scope.

- location:

  Local study path or GitHub address. When set, builds outputs for that
  study repository (equivalent to passing its DOI with
  `what = "everything"`).

- registry_root:

  Optional registry checkout for monorepo dev. Used with
  `doi = "everywhere"` or `location`.

- folders:

  Optional character vector of registry folder names when
  `doi = "everywhere"`. Defaults to all `studies/*.yml` stubs.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name (for a single `doi`).

- language:

  Optional engine language for multi-engine replications.

- install_deps:

  Logical. Install missing dependencies when `TRUE`.

- only_missing:

  Logical. When `TRUE`, skip replications whose artifacts already exist
  (see
  [`artifact_available()`](https://replicate-anything.github.io/replicateEverything/reference/artifact_available.md)).

- force_prep:

  Logical. Re-run prep steps even when outputs already exist.

## Value

Invisibly `TRUE` on success for a single study, or (when
`doi = "everywhere"`) a list with `built`, `skipped`, and `failures`.

## See also

[`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md),
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
build_outputs(doi = "10.1177/00491241211036161", what = "fig_1")
build_outputs(doi = "10.1177/00491241211036161", what = "everything")
build_outputs(location = ".")
build_outputs(doi = "10.1177/00491241211036161", what = "tab_1", only_missing = TRUE)
options(replicateEverything.registry_root = "../registry")
build_outputs(doi = "everywhere", what = "everything")
build_outputs(doi = "everywhere", folders = "10.1177_00491241211036161")
} # }
```
