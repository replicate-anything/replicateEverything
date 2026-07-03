# Stata command-line arguments for non-interactive do-file execution

Windows: `/e do file.do`. Unix/Linux/macOS: `-b file.do`. Paths with
spaces are shortened on Windows when possible.

## Usage

``` r
stata_batch_args(do_path)
```

## Arguments

- do_path:

  Path to the do-file.

## Value

Character vector of arguments for
[`system2()`](https://rdrr.io/r/base/system2.html).
