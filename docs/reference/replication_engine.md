# Replication engine for a single entry

Replication engine for a single entry

## Usage

``` r
replication_engine(rep, paper_meta = NULL)
```

## Arguments

- rep:

  Replication entry from `replication.yml`.

- paper_meta:

  Optional paper-level metadata.

## Value

`"r"`, `"stata"`, `"python"`, `"dataverse"`, or `"mathematica"`
(system-tool engines used for missing-tool / incomplete-step display,
e.g. an alternate-engine `group:` member that is never dispatched by
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)).
