# Validate resolvable code file links in a folder-backed study

Returns checklist rows suitable for
[`bind_check_results`](https://replicate-anything.github.io/replicateEverything/reference/bind_check_results.md).
Called from
[`check_folder_replication`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
before registry submission.

## Usage

``` r
check_code_links(study_root, meta)
```

## Arguments

- study_root:

  Absolute study root directory.

- meta:

  Parsed replication metadata.

## Value

Data frame of checklist results (`check`, `passed`, `message`).
