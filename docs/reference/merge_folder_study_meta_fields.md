# Merge study-repo fields into registry stub metadata

Registry stubs omit `replications`, `stata_deps_probe`, and related
study-repo-only fields. Overlay them from the folder-backed study yaml.

## Usage

``` r
merge_folder_study_meta_fields(meta, study_meta)
```

## Arguments

- meta:

  Parsed metadata (often a registry stub).

- study_meta:

  Full `replication.yml` from the study repo.

## Value

Updated `meta` list.
