# Reason an audit job should be recorded as skipped (not executed)

Skips yaml `incomplete: true` steps (including `requires_engine:` and
`data_unavailable:` gaps), and steps that declare a missing
proprietary/system engine even when `incomplete` was omitted.

## Usage

``` r
audit_step_skip_reason(rep)
```
