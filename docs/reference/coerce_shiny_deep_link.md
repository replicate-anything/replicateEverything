# Coerce a Shiny client deep-link payload to a normalized list

Accepts a list or named vector from `Shiny.setInputValue()` and a bare
DOI string. Study-only: `doi` or `handle`. Legacy `what` / `language`
fields are ignored if present.

## Usage

``` r
coerce_shiny_deep_link(x)
```

## Arguments

- x:

  Client payload for `url_deep_link`.

## Value

List with `doi` (study key), or `NULL`.
