# Install dependencies for every study in the registry index

Maintainer setup for a shared server or audit machine. Calls
[`install_study_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_study_dependencies.md)
for each row in
[`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md).
Failures are collected and reported; other studies continue. Called by
[`install_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_dependencies.md)
with `what = "everywhere"`.

## Usage

``` r
install_registry_dependencies(registry_root = NULL, verbose = TRUE)
```

## Arguments

- registry_root:

  Optional registry checkout path.

- verbose:

  Logical. Print progress lines.

## Value

Invisibly, a named list of per-DOI results (`ok` / `error`).

## See also

[`install_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_dependencies.md),
[`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md)
