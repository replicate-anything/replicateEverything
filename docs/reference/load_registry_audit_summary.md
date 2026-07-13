# Load the registry audit summary

Reads `audit_summary.json` from a local registry checkout when
available; otherwise fetches from GitHub.

## Usage

``` r
load_registry_audit_summary(registry_root = NULL)
```

## Arguments

- registry_root:

  Optional registry repository root.

## Value

A list with summary counts, or `NULL` when unavailable.
