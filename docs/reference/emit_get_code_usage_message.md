# Usage tip printed by [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md) (any mode)

Usage tip printed by
[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
(any mode)

## Usage

``` r
emit_get_code_usage_message(
  engine = NULL,
  type = NULL,
  rep = NULL,
  lines = NULL,
  doi = NULL,
  what = NULL
)
```

## Arguments

- engine:

  `"r"`, `"stata"`, or `"python"` (default `"r"`).

- type:

  Optional step type from yaml.

- rep:

  Optional replication / step entry (yaml-implied R recipe; Stata/Python
  path).

- lines:

  Optional script lines (so R tips detect generate\_\* names).

- doi, what:

  Optional concrete ids; placeholders when omitted.
