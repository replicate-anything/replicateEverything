# System engines required by incomplete / blocked steps (e.g. Mathematica)

Scans `requires_engine:` / `system_requirements:` / blocked-reason text
on steps marked `incomplete: true`. Does not include ordinary
replication engines (R / Stata / Python).

## Usage

``` r
study_required_system_engines(meta)
```

## Arguments

- meta:

  Parsed replication metadata, or a list of step entries.

## Value

Character vector of display names (e.g. `"Mathematica"`).
