# Git ref for folder-backed study materials

Git ref for folder-backed study materials

## Usage

``` r
study_repo_ref(meta, ctx = NULL)
```

## Arguments

- meta:

  Parsed replication.yml contents.

- ctx:

  Optional paper / step context; when set, prefers `ctx$materials_ref`
  (parent ref for inherited steps).

## Value

Character branch, tag, or commit.
