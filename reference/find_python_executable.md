# Find a Python executable

When `deps` is non-empty, prefers the first candidate that can import
every declared package (helps on Windows where `Sys.which("python")` may
point at a Store stub while packages live in another install).

## Usage

``` r
find_python_executable(deps = NULL)
```

## Arguments

- deps:

  Optional character vector of PyPI dependency specs.

## Value

Character path.
