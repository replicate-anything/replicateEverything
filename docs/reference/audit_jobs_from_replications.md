# List audit jobs (one row per engine) from replication entries

Incomplete / blocked steps are included with a non-empty `skip_reason`
so the audit can record them as **Skipped** without executing them.
Runnable jobs are display steps (figure / table) only.

## Usage

``` r
audit_jobs_from_replications(reps)
```

## Arguments

- reps:

  List of replication entries from
  [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md).

## Value

Data frame with columns `group`, `what`, `engine`, `label`, `type`, and
`skip_reason`.
