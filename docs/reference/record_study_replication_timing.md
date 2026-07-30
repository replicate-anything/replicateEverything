# Record a successful bake / run timing for one step

Writes (or updates) `outputs/replication_timings.json` under the study
root. Safe to call from bake helpers; failures are swallowed so they
never break a successful replication.

## Usage

``` r
record_study_replication_timing(
  study_root,
  step_id,
  seconds,
  engine = NULL,
  status = "ok"
)
```

## Arguments

- study_root:

  Study repository root.

- step_id:

  Step id.

- seconds:

  Elapsed seconds.

- engine:

  Optional engine label.

- status:

  Optional status string (default `"ok"`).

## Value

Invisibly, the path written (or `NULL` on skip/failure).
