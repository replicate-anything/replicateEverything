# Install instructions for a package-backed study

Install instructions for a package-backed study

## Usage

``` r
study_package_install_info(meta, ctx)
```

## Arguments

- meta:

  Parsed replication metadata (registry stub or package yaml).

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

A list with `package`, `repo`, `ref`, `github_url`, `install_github`,
and optional `sibling_path` / `load_local`.
