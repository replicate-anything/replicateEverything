# Resolve Stata dependency install scripts for a study

Looks for `code/helpers/install_stata_deps.do` and optional
`stata_dependencies` entries in replication metadata.

## Usage

``` r
stata_deps_install_scripts(study_root, meta = NULL, rep = NULL)
```

## Arguments

- study_root:

  Local study repository root.

- meta:

  Optional parsed replication metadata.

- rep:

  Optional replication entry.
