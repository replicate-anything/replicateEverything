# Exit code that made a generated Stata probe fail, if attributable

[`stata_runner_lines()`](https://replicate-anything.github.io/replicateEverything/reference/stata_runner_lines.md)
always prints `"...ended with error r(<code>);..."` when the wrapped
do-file aborts, and Stata itself echoes a bare `r(<code>);` line for the
underlying `exit <code>`. Either is enough to recover the first failing
exit code from the run's error text.

## Usage

``` r
stata_probe_failure_code(text)
```

## Arguments

- text:

  Character scalar (e.g.
  [`conditionMessage()`](https://rdrr.io/r/base/conditions.html) of the
  error thrown by
  [`run_stata_do()`](https://replicate-anything.github.io/replicateEverything/reference/run_stata_do.md),
  which includes the Stata error/log tail).

## Value

Character scalar exit code, or `NA_character_` if none found.
