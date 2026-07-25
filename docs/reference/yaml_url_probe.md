# Probe a local path or HTTP(S) yaml URL

Distinguishes network failure, HTTP 404/403, empty body, and parse
errors so callers can build specific user-facing messages.

## Usage

``` r
yaml_url_probe(url)
```

## Arguments

- url:

  Local path or HTTP(S) URL.

## Value

A list with `ok`, `status`, `status_code`, `parsed`, and `parse_error`.
