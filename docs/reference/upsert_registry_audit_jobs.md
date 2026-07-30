# Upsert job rows into the registry CSV (by doi × object × engine)

Upsert job rows into the registry CSV (by doi × object × engine)

## Usage

``` r
upsert_registry_audit_jobs(new_rows, registry_root = NULL)
```

## Arguments

- new_rows:

  Jobs data frame to merge in.

- registry_root:

  Registry root.

## Value

Invisibly, the merged jobs data frame.
