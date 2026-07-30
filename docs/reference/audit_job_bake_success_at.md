# Look up bake / artifact fallback for last_success_at

Prefers `recorded_at` from study bake timings; else artifact mtime.

## Usage

``` r
audit_job_bake_success_at(
  doi,
  object,
  engine = NULL,
  repo = NULL,
  folder = NULL,
  study_root = NULL
)
```
