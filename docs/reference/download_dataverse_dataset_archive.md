# Download a full Dataverse dataset as a zip archive

Use `format=original` so tabular uploads arrive as CSV/Stata/etc., not
Dataverse `.tab` exports.

## Usage

``` r
download_dataverse_dataset_archive(
  dataset,
  dest_zip,
  server = "dataverse.harvard.edu",
  original = TRUE,
  timeout = 3600
)
```

## Arguments

- dataset:

  Dataverse dataset DOI or persistent id.

- dest_zip:

  Destination `.zip` path.

- server:

  Dataverse host.

- original:

  When `TRUE`, request native uploads (`format=original`).

- timeout:

  Seconds for the HTTP request.
