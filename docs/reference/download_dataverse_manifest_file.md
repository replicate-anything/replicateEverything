# Download a single file listed in a Dataverse manifest row

Manifest columns:

- id:

  Dataverse file id

- path:

  Local path under the deposit root (author-relative layout)

- original:

  When `TRUE`, fetch native upload via `?format=original` (e.g. CSV
  behind a `.tab` name on Dataverse)

## Usage

``` r
download_dataverse_manifest_file(
  row,
  deposit_root,
  server = "dataverse.harvard.edu"
)
```

## Arguments

- row:

  One row from a manifest data frame.

- deposit_root:

  Directory to write into (e.g. `outputs/deposit`).

- server:

  Dataverse host.

## Value

Invisibly, the destination path.
