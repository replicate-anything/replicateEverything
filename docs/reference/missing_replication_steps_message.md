# User-facing explanation when replication steps cannot be listed

Distinguishes private/404/network fetch failures, yaml parse problems,
and a genuine empty stub. Shiny surfaces this via
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
errors and `replication_error_message()`.

## Usage

``` r
missing_replication_steps_message(meta, ctx = NULL, normalize_error = NULL)
```

## Arguments

- meta:

  Parsed registry stub or study metadata.

- ctx:

  Optional paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

- normalize_error:

  Optional normalize/parse error to prefer when the study yaml was
  already loaded (e.g. deprecated `artifact:`).

## Value

Character scalar.
