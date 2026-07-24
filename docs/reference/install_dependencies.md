# Install declared dependencies for a study, or for the whole registry

Single maintainer entry point for dependency setup. Mirrors the
[`build_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_outputs.md)
/
[`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md)
scope pattern: pass a study location to install for one study, or
`what = "everywhere"` to install for every study in the registry index
(see
[`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)).

## Usage

``` r
install_dependencies(
  what = ".",
  registry_root = NULL,
  repo = NULL,
  folder = NULL,
  verbose = TRUE
)
```

## Arguments

- what:

  Study DOI, registry handle, local path, or GitHub slug (default `"."`,
  the current working directory); or `"everywhere"` to install
  dependencies for every study in the registry index.

- registry_root:

  Optional registry checkout for monorepo dev.

- repo, folder:

  Optional registry row hints. Ignored when `what = "everywhere"`.

- verbose:

  Logical. Print progress lines. Only used when `what = "everywhere"`.

## Value

Invisibly `TRUE` for a single study, or (when `what = "everywhere"`) a
named list of per-DOI results (`ok` / `error`).

## See also

[`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md),
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md),
[`build_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_outputs.md),
[`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
install_dependencies("10.1017/S0003055426101749")
install_dependencies("path/to/study-repo")
options(replicateEverything.registry_root = "../registry")
install_dependencies("everywhere")
} # }
```
