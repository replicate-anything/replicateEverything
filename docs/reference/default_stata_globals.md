# Default Stata path globals for a study root

Matches `code/helpers/init_study_paths.do` in folder-backed studies.
`maindir` is the study root (directory containing `replication.yml`).

## Usage

``` r
default_stata_globals(study_root, result_dir = NULL)
```

## Arguments

- study_root:

  Normalized absolute study root path.

- result_dir:

  Optional override for `result` (e.g. staging dir).

## Value

Named character vector of global values.
