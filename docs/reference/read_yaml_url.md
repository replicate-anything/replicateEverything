# Read yaml from an HTTP(S) URL without writing a temp file

Avoids [`download.file()`](https://rdrr.io/r/utils/download.file.html)
temp-path failures on some Shiny servers.

## Usage

``` r
read_yaml_url(url)
```

## Arguments

- url:

  Character URL.

## Value

Parsed yaml list or `NULL`.
