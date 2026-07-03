# Directory for ephemeral Stata runner scripts and batch logs

Runners and Stata batch logs live under the R session temp directory so
study repos are not littered with `artifacts/staging/.run` and paths
with spaces do not break the Stata command line.

## Usage

``` r
stata_run_dir(workdir, staging_dir = NULL)
```

## Arguments

- workdir:

  Study repository root.

- staging_dir:

  Writable staging directory for replication output.
