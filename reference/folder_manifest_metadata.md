# Portable study metadata for artifacts/manifest.json

Committed manifests should reference the GitHub slug and
monorepo-relative folder name, not machine-specific absolute paths.

## Usage

``` r
folder_manifest_metadata(study_root, meta)
```

## Arguments

- study_root:

  Normalized study repository path.

- meta:

  Parsed study `replication.yml`.
