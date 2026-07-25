# Download a URL to a local path (skip if present unless force)

Thin httr wrapper used by declared-data materialize. Prefer this over
study-local download helpers.

## Usage

``` r
download_url_to_path(url, dest, force = FALSE, timeout = 600)
```

## Arguments

- url:

  Remote URL.

- dest:

  Destination path.

- force:

  Re-download even when `dest` exists and is non-empty.

- timeout:

  Seconds.

## Value

Invisibly, `dest`.
