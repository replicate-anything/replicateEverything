# Prep / transform steps to run before building display artifacts

When `display_reps` is `NULL`, returns every transform step. Otherwise
returns only ancestors required by the given display steps.

## Usage

``` r
prep_steps_for_build(meta, display_reps = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- display_reps:

  Optional list of table/figure entries being built.
