# Write registry stub files into a study repository

Creates the short registry yaml and one-row `index.csv` under
`registry/` (folder studies) or `inst/registry/` (package studies).

## Usage

``` r
write_study_registry_stub(location = ".", stub_dir = NULL)

write_folder_registry_stub(location = ".", stub_dir = NULL)
```

## Arguments

- location:

  Study repo path. Defaults to `"."`.

- stub_dir:

  Optional override for the handoff directory.

## Value

List with `stub_dir`, `stub_path`, `index_path`, `folder`, and `kind`.
