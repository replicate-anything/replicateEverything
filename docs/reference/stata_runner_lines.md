# Build the do-file lines for the package's generated Stata batch runner

Always wraps the actual step do-file in `capture noisily do ...` (never
a bare `do ...`). On Windows, an uncaught runtime error during a batch
run (`/e do ...`) - anywhere in the step's do-file or in any do-file it
calls, however deeply nested - otherwise pops a modal ".do has been
interrupted. Would you like the batch job to continue?" dialog that
blocks headless/unattended runs indefinitely (confirmed on Stata 10-19;
happens with both `/e` and `/b` - `/e` only suppresses the separate "job
finished, click OK" dialog on success). `capture` around the outermost
`do` absorbs an uncaught error in that do-file (and in nested `do`s that
abort into it) so the batch process is not left in an "interrupted"
state. `noisily` keeps the usual output and the `r(###);` line in the
log so `stata_log_error()` still detects the failure.

## Usage

``` r
stata_runner_lines(do_in_do, wd_in_do, staging_dir = NULL)
```

## Arguments

- do_in_do:

  Do-file path already escaped/formatted for use inside a Stata do-file
  (see `stata_path_in_do()`).

- wd_in_do:

  Working directory, same formatting.

- staging_dir:

  Optional writable directory for `$result` output.

## Value

Character vector of do-file lines.

## Details

The preamble also forces non-interactive preferences that author code
sometimes re-enables: `set more off` and `pause off`. The study `do` is
run under `nobreak` so a Break keypress cannot abort the batch job with
`r(1)`. We intentionally do *not* set `varabbrev off`: many deposited
scripts rely on Stata's default abbreviation matching. Studies may still
wrap their own nested `do` calls in `capture noisily` as defense in
depth.
