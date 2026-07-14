# Whether replication runs may install missing dependencies

Live Run and Shiny verify only. Maintainer builds set
`options(replicateEverything.install_dependencies = TRUE)` (as
`build_study_outputs(install_deps = TRUE)` does).

## Usage

``` r
allow_dependency_install(want = FALSE)
```

## Arguments

- want:

  Caller requested `install_deps = TRUE`.

## Value

Logical scalar.
