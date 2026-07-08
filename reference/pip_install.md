# Run `pip` and return its exit status and output

Uses `stdout/stderr = TRUE`, so the return value of
[`system2()`](https://rdrr.io/r/base/system2.html) is captured output;
the exit code lives in its `"status"` attribute.

## Usage

``` r
pip_install(python, args)
```

## Arguments

- python:

  Path to the Python executable.

- args:

  Character vector of arguments following `-m pip`.

## Value

List with integer `status` and character `output`.
