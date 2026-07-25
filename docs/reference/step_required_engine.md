# Required proprietary/system engine for a blocked step, if declared or inferred

Prefers structured yaml `requires_engine:` (or `system_requirements:`),
then parses common names out of `blocked_reason:`.

## Usage

``` r
step_required_engine(entry)
```
