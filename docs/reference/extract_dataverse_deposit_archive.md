# Extract a Dataverse dataset zip into a deposit directory

Unzips in place. If the archive contains a single top-level directory
that holds `data/` or `scripts/`, that wrapper is hoisted away.

## Usage

``` r
extract_dataverse_deposit_archive(zip_path, deposit_root, clean = TRUE)
```

## Arguments

- zip_path:

  Path to the downloaded archive.

- deposit_root:

  Target directory (e.g. `outputs/deposit`).

- clean:

  When `TRUE`, remove existing deposit contents except the zip.
