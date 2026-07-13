# List audit jobs (one row per engine) from replication entries

List audit jobs (one row per engine) from replication entries

## Usage

``` r
audit_jobs_from_replications(reps)
```

## Arguments

- reps:

  List of replication entries from
  [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md).

## Value

Data frame with columns `group`, `what`, `engine`, `label`, and `type`.
