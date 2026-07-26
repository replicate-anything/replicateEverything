# Resolve Stata output path after a run

Resolve Stata output path after a run

## Usage

``` r
resolve_stata_output_after_run(
  rep,
  study_root,
  staging_dir = NULL,
  before_mtimes = NULL
)
```

## Arguments

- rep:

  Replication entry.

- study_root:

  Study repository root.

- staging_dir:

  Optional writable staging directory.

- before_mtimes:

  Optional snapshot from
  [`stata_output_mtime_snapshot()`](https://replicate-anything.github.io/replicateEverything/reference/stata_output_mtime_snapshot.md);
  when supplied, only files that are new or whose mtime/size changed
  count as the run's output.
