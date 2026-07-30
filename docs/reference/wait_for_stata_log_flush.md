# Wait for a just-written Stata batch log to stop growing on disk

Polls the file size a few times with a short pause. If the Stata child
process has fully exited (which
[`run_stata_system2()`](https://replicate-anything.github.io/replicateEverything/reference/run_stata_system2.md)
already waited for), a stable size for 2 consecutive checks means the OS
has finished flushing writes and it is safe to
[`readLines()`](https://rdrr.io/r/base/readLines.html).

## Usage

``` r
wait_for_stata_log_flush(log_path, max_checks = 10L, interval = 0.3)
```
