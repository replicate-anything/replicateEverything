# Build a single precomputed output

Build a single precomputed output

## Usage

``` r
build_single_output(
  doi,
  what,
  only_missing = FALSE,
  install_deps = TRUE,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  force_prep = FALSE,
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

- only_missing:

  Logical. When `TRUE`, skip when the artifact already exists.

- install_deps:

  Logical. Install missing dependencies when `TRUE`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name (for a single `doi`).

- registry_root:

  Optional registry checkout for monorepo dev. Used with
  `doi = "everywhere"` or `location`.

- force_prep:

  Logical. Re-run prep steps even when outputs already exist.

- language:

  Optional engine language for multi-engine replications.

## Value

Invisibly `TRUE` on success.
