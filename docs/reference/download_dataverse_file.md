# Download a Harvard Dataverse file by id

Prefers surgical file-level fetches
(`api/access/datafile/<id>?format=original`) over full dataset archives.
Studies should call
[`fetch_dataverse_file()`](https://replicate-anything.github.io/replicateEverything/reference/fetch_dataverse_file.md)
rather than inventing local
[`httr::GET`](https://httr.r-lib.org/reference/GET.html) helpers.

## Usage

``` r
download_dataverse_file(
  file_id,
  dest,
  server = "dataverse.harvard.edu",
  original = FALSE,
  force = TRUE,
  timeout = 600
)
```

## Arguments

- file_id:

  Dataverse numeric file id.

- dest:

  Destination path.

- server:

  Dataverse host.

- original:

  When `TRUE`, append `?format=original` (native upload).

- force:

  Re-download even when `dest` exists and is non-empty.

- timeout:

  Seconds.

## Value

Invisibly, `dest`.
