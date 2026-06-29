# Download a registry or package file to a temp path

Uses `httr` for HTTP(S) URLs to avoid
[`download.file()`](https://rdrr.io/r/utils/download.file.html)
temp-path failures on some Shiny servers.

## Usage

``` r
download_registry_file(url)
```

## Arguments

- url:

  HTTP(S) URL or local path.

## Value

Character path to temp file.
