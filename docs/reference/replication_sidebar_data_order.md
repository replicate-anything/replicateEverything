# Sidebar keys for Data steps in yaml / DAG declaration order

Returns unique `group:` (or `id` when ungrouped) keys for transform/prep
steps, preserving first-appearance order in `reps`. Multi-path siblings
that share a `group:` collapse to one key so the Shiny sidebar does not
list the claim twice. Used to interleave promoted path-group transforms
with ordinary prep rows instead of rendering multi-path groups first.

## Usage

``` r
replication_sidebar_data_order(reps)
```

## Arguments

- reps:

  List of replication / step entries (yaml order).

## Value

Character vector of sidebar keys.
