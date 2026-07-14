# Install dependencies for a package-backed study

Loads or installs the study package, then installs declared R, Python,
and Stata dependencies from its `replication.yml`. Does not build
`inst/report/outputs/` — use
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)
for that.

## Usage

``` r
install_package_dependencies(meta, ctx)
```

## Arguments

- meta:

  Parsed replication metadata with `paper.package`.

- ctx:

  Paper context.
