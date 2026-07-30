# Human Display summary for transform / prep sinks (.done, dirs, products)

Prefer this over dumping marker-file text. Uses optional yaml
`products:` / `display_products:`, the output directory inventory, and a
completion stamp from `.done` when present.

## Usage

``` r
summarize_prep_transform_sink(meta, ctx, prep, path = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

- prep:

  Prep / transform step entry.

- path:

  Primary output path (often a `.done` marker).

## Value

A `prep_output_preview` with a multi-line `note`.
