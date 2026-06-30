# Build base URLs and paths for a paper in the registry

Registry stubs live as `papers/<folder>.yml` files. For folder-backed
external studies, materials live at the study repo root. For
package-backed studies, the registry stub path is still exposed but
materials are resolved via the study package API.

## Usage

``` r
paper_context(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug. Defaults to `find_repo(doi)`.

- folder:

  Optional registry folder name from `index.csv`.

## Value

A list with `repo`, `folder`, `base_url`, `registry_local_root`,
`local_root`, `materials_repo`, `is_folder_study`, and related fields.
