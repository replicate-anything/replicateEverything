# Download only manifest-listed Dataverse files (surgical Pattern C)

When the manifest has an `id` column, fetches each file by id into the
deposit layout. Prefer this over
[`access_dataverse_deposit_archive()`](https://replicate-anything.github.io/replicateEverything/reference/access_dataverse_deposit_archive.md)
unless author scripts require a full deposit tree that cannot be
reconstructed from file ids.

## Usage

``` r
access_dataverse_deposit_manifest_files(
  manifest_df,
  deposit_root,
  server = "dataverse.harvard.edu",
  force = TRUE
)
```

## Arguments

- manifest_df:

  Manifest data frame with `id` and `path`.

- deposit_root:

  Deposit directory.

- server:

  Dataverse host.

- force:

  Re-download existing files.

## Value

Invisibly, character vector of destination paths.
