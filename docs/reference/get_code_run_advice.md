# How-to-run advice shared by [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md) tips and the Code tab setup box

Guidance for using the displayed script (not the package Live Run path).
Does not mention optional
[`sys.nframe()`](https://rdrr.io/r/base/sys.parent.html) script footers.
Returns a working-directory note plus a numbered list under
`"To produce the <kind>:"`.

## Usage

``` r
get_code_run_advice(
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

Character vector of advice lines (no `get_code() returns...` preamble).
