# Enable maintainer-only dependency installation for a code block

Sets `replicateEverything.install_dependencies` and
`replicateEverything.install_stata_deps` to `TRUE`, then restores
previous values on exit.

## Usage

``` r
with_maintainer_install_opts(code)
```

## Arguments

- code:

  Expression to evaluate.

## Value

Value of `code`.
