# Prep steps to run before building display artifacts

When `display_reps` is `NULL`, returns every entry in `prep:`. Otherwise
returns only prep steps required by the given replications.

## Usage

``` r
prep_steps_for_build(meta, display_reps = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- display_reps:

  Optional list of table/figure entries being built.
