# Directory for registry handoff files inside a study repository

Folder-backed studies use `registry/`. Package-backed studies use
`inst/registry/` (preferred) or legacy `registry/` at the package root.

## Usage

``` r
study_registry_stub_dir(study_root, kind = NULL, create = FALSE)
```

## Arguments

- study_root:

  Normalized study repository path.

- kind:

  `"folder"` or `"package"`. Inferred when omitted.

- create:

  If `TRUE`, create the directory when missing.
