# Look up audit runtime for one study object

Reads the registry `audit_latest.rds` snapshot when available and
returns elapsed seconds and a short/medium/slow category for Shiny Run
advice.

## Usage

``` r
lookup_replication_audit_runtime(
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

List with `available`, `seconds`, `runtime_category`, `advice`,
`timed_out`, and matching `object`.
