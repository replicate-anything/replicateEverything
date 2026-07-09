# Write registry stub files into a study repository

Creates `registry/replication.yml` and `registry/index.csv` (one row)
under the study repo. After
[`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md)
passes, copy these into the [registry
repository](https://github.com/replicate-anything/registry):

## Usage

``` r
write_folder_registry_stub(location = ".", stub_dir = NULL)
```

## Arguments

- location:

  Study repo path. Defaults to `"."`.

- stub_dir:

  Subdirectory under the study root; default `"registry"`.

## Value

List with `stub_dir`, `stub_path`, `index_path`, and `folder`.

## Details

- `registry/replication.yml` -\> `papers/<folder>.yml`

- merge `registry/index.csv` into `index.csv`
