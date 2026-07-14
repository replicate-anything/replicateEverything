# Resolve a referenced code path within a study root

Resolve a referenced code path within a study root

## Usage

``` r
resolve_code_path(
  path,
  study_root,
  globals = character(),
  from_file = NULL,
  allowed_root = study_root
)
```

## Arguments

- path:

  Raw path from a `do`/`source` call.

- study_root:

  Absolute study root directory.

- globals:

  Named character vector of Stata globals.

- from_file:

  Optional path of the file containing the call (for relative paths).

- allowed_root:

  Optional permitted root (defaults to `study_root`).

## Value

List with `status` (`ok`, `missing`, `unresolved`, `outside_root`,
`unreadable`), `resolved`, `display`, `unresolved`.
