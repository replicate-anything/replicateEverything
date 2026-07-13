# Run a Stata do-file non-interactively

Run a Stata do-file non-interactively

## Usage

``` r
run_stata_do(
  do_path,
  workdir,
  timeout = 900L,
  staging_dir = NULL,
  hint_context = NULL
)
```

## Arguments

- do_path:

  Path to the do-file.

- workdir:

  Working directory Stata should use.

- timeout:

  Seconds before aborting (best effort on Windows).

- staging_dir:

  Optional writable directory for `$result` output.

## Value

A `stata_run_result` list with log path and diagnostics.
