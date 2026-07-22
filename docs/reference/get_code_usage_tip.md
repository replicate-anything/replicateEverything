# Single tip string for [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md) (any mode)

Engine- and yaml-aware. Shared body from
[`get_code_run_advice()`](https://replicate-anything.github.io/replicateEverything/reference/get_code_run_advice.md).
Multiline numbered list (blank line after the preamble).

## Usage

``` r
get_code_usage_tip(
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

## Value

Character scalar tip.
