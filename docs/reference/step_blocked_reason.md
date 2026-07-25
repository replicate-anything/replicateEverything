# Human-readable reason a step is unavailable, or NULL when it is runnable

Reads the `incomplete:` / `blocked_reason:` fields declared on a step in
`replication.yml`. `incomplete: true` with no `blocked_reason` still
blocks the step, using a generic message.

## Usage

``` r
step_blocked_reason(meta, what)
```
