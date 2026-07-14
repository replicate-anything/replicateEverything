# Validate precomputed outputs

Maintainer helper: checks that declared table and figure outputs exist
on disk (folder-backed studies: study repo `outputs/`; package-backed:
installed package report outputs). Does not run live replications.

## Usage

``` r
validate_outputs(
  doi = NULL,
  what = NULL,
  location = NULL,
  registry_root = NULL,
  folders = NULL,
  repo = NULL,
  folder = NULL,
  language = NULL
)
```

## Arguments

- doi:

  Character DOI, or `"everywhere"` to check every registry study.
  Ignored when `location` is set.

- what:

  Replication id, or `"everything"` (default when `doi` or `location` is
  set) to check every table and figure in scope.

- location:

  Local study path or GitHub address. When set, validates outputs for
  that study repository (equivalent to passing its DOI with
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

## Value

Invisibly `TRUE` on success.

## See also

[`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md),
[`build_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_outputs.md),
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
validate_outputs(doi = "10.1177/00491241211036161", what = "fig_1")
validate_outputs(doi = "10.1177/00491241211036161", what = "everything")
validate_outputs(location = ".")
options(replicateEverything.registry_root = "../registry")
validate_outputs(doi = "everywhere", what = "everything")
validate_outputs(doi = "everywhere", folders = "10.1177_00491241211036161")
} # }
```
