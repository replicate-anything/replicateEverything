# Retry an expression after installing a missing package

Retry an expression after installing a missing package

## Usage

``` r
retry_with_missing_package(expr, install_missing = FALSE, max_attempts = 2)
```

## Arguments

- expr:

  Expression to evaluate.

- install_missing:

  Logical. Whether package installation is allowed.

- max_attempts:

  Maximum number of attempts.
