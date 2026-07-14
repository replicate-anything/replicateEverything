# Build all precomputed outputs for one paper

Build all precomputed outputs for one paper

## Usage

``` r
build_paper_outputs(
  doi,
  only_missing = FALSE,
  install_deps = TRUE,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  force_prep = FALSE
)
```

## Arguments

- doi:

  Character. DOI of the paper.

- only_missing:

  Logical. When `TRUE`, skip when the artifact already exists.

- install_deps:

  Logical. Install missing dependencies when `TRUE`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name.

- registry_root:

  Optional registry checkout for monorepo dev. Used with
  `doi = "everywhere"` or `location`.

- force_prep:

  Logical. Re-run prep steps even when outputs already exist.

## Value

Invisibly `TRUE` on success.
