# Whether script lines call make\_() outside its definition

Detects optional top-level / footer calls. Not required for Live Run —
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
loads definitions and calls `make_*` from yaml.

## Usage

``` r
script_has_make_call(lines, what)
```

## Arguments

- lines:

  Character vector of script lines.

- what:

  Replication identifier.

## Value

Logical scalar.
