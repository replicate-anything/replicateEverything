# Caption for a prep / transform step in Shiny and reports

Prefers a short `path_note:` when present, otherwise a truncated
`description:`, so Display banners stay readable.

## Usage

``` r
prep_step_display_caption(prep)
```

## Arguments

- prep:

  Prep step entry from `replication.yml`.

## Value

Character string like `` `Analysis data` step (Rename ...) ``.
