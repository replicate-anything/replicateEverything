# Walk up directory tree until a relative path exists

Walk up directory tree until a relative path exists

## Usage

``` r
walk_up_for_relative(start, relative, max_depth = 12L)
```

## Arguments

- start:

  Starting directory.

- relative:

  Path relative to each candidate root.

- max_depth:

  Maximum levels to ascend.

## Value

Normalized directory containing `relative`, or `NULL`.
