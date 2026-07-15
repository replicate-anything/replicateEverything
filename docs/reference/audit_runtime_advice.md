# Human-readable expected-time advice from an audit runtime category

Human-readable expected-time advice from an audit runtime category

## Usage

``` r
audit_runtime_advice(category, seconds = NULL)
```

## Arguments

- category:

  `"short"`, `"medium"`, or `"slow"`.

- seconds:

  Optional elapsed seconds from the last audit for a more specific tip.

## Value

Character scalar (may be empty when category is missing).
