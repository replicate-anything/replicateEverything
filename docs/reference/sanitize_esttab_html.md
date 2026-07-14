# Clean LaTeX fragments from esttab HTML output

esttab's `mgroups(..., prefix(\multicolumn{...}))` option emits raw
LaTeX into HTML tables. This helper strips those fragments and applies
simple colspan fixes for two-group headers.

## Usage

``` r
sanitize_esttab_html(html)
```

## Arguments

- html:

  Character HTML string.

## Value

Character HTML.
