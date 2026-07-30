# Prep / transform steps to run before building display artifacts

When `display_reps` is `NULL`, returns every runnable transform step
(skips `incomplete:` / blocked paths such as Mathematica-only siblings).
Otherwise returns only ancestors required by the given display steps,
still excluding incomplete entries.

## Usage

``` r
prep_steps_for_build(meta, display_reps = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- display_reps:

  Optional list of table/figure entries being built.
