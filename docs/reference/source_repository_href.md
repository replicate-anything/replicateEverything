# Browse URL for a source-repository credit

Returns an http(s) URL when `value` is already a link, or maps the bare
credit `"replicateEverything"` to the package GitHub page.

## Usage

``` r
source_repository_href(value)
```

## Arguments

- value:

  Character from
  [`paper_source_repository()`](https://replicate-anything.github.io/replicateEverything/reference/paper_source_repository.md).

## Value

Character URL, or `NULL`.
