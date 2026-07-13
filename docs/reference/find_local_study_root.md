# Find a folder-backed study root containing `replication.yml`

Walks up from `location` (default working directory).

## Usage

``` r
find_local_study_root(location = getwd())
```

## Arguments

- location:

  Directory to start from.

## Value

Normalized study root or `NULL`.
