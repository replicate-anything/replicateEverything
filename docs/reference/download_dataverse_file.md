# Download a Harvard Dataverse file by id

Download a Harvard Dataverse file by id

## Usage

``` r
download_dataverse_file(
  file_id,
  dest,
  server = "dataverse.harvard.edu",
  original = FALSE
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
