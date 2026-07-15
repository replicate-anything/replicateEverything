# Resolve a prep display value to a kable-ready preview when possible

Accepts a data frame, `replication_result`, or `prep_output_preview` and
returns a data frame head when the backing file is tabular.

## Usage

``` r
resolve_prep_display_object(obj, n = 6L)
```

## Arguments

- obj:

  Artifact, replication result, or preview object.

- n:

  Maximum preview rows.
