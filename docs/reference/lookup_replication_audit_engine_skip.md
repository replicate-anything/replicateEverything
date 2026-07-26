# Whether registry audit skipped a step for a missing-engine reason

Used by Shiny to prefer audit signals for hammer Run-slot chrome when
display outputs are missing.

## Usage

``` r
lookup_replication_audit_engine_skip(
  doi,
  what,
  engine = NULL,
  registry_root = NULL
)
```

## Arguments

- doi:

  Study DOI.

- what:

  Replication id (or group id).

- engine:

  Optional engine filter (`"r"`, `"stata"`, `"python"`).

- registry_root:

  Optional registry root.

## Value

List with `skipped_engine` and `reason`.
