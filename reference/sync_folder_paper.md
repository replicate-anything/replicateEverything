# Copy prepared registry files into the registry repository

Reads `registry/replication.yml` and `registry/index.csv` from the study
repo (written by
[`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md))
and installs them in a local registry checkout.

## Usage

``` r
sync_folder_paper(location = ".", registry_root = NULL)
```

## Arguments

- location:

  Study repo path. Defaults to `"."`.

- registry_root:

  Path to the registry repository root. Defaults to
  `getOption("replicateEverything.registry_root")`.

## Value

Invisibly, a list with `stub_path`, `index_updated`, and `folder`.

## Examples

``` r
if (FALSE) { # \dontrun{
options(replicateEverything.registry_root = "../registry")
sync_folder_paper(".")
} # }
```
