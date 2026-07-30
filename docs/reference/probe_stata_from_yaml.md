# Probe Stata from yaml declarations (executable + probe or stata_packages)

Always reports the resolved Stata executable (`stata_executable` /
`stata_label`) alongside `ok` / `missing`, so
[`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md)
output makes it obvious which Stata binary was probed - and whether it's
the same one
[`install_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_dependencies.md)
used (see
[`stata_executable_label()`](https://replicate-anything.github.io/replicateEverything/reference/stata_executable_label.md)).

## Usage

``` r
probe_stata_from_yaml(meta, study_root = NULL)
```
