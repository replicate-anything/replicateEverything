# Run Stata in batch mode with an optional timeout

Uses processx when available so overdue runs can be killed and the R
session (e.g. Shiny) can continue. Without processx, runs block with no
timeout (legacy behaviour).

## Usage

``` r
run_stata_system2(stata, batch_args, timeout = 900L)
```

## Arguments

- stata:

  Path to Stata executable.

- batch_args:

  Character vector of batch arguments.

- timeout:

  Seconds; `0` or negative means no limit.

## Value

Integer exit status (0 = success).
