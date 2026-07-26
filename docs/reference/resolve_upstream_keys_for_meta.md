# Resolve upstream keys for one study meta against the registry index

Returns matched registry keys when possible; otherwise a normalized DOI
(so Shiny can still link out to doi.org).

## Usage

``` r
resolve_upstream_keys_for_meta(meta, index)
```
