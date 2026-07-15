# Collect broken code file references in a folder-backed study

Walks every replication script declared in `replication.yml`, parses
[`source()`](https://rdrr.io/r/base/source.html),
[`sys.source()`](https://rdrr.io/r/base/sys.source.html), and Stata
`do`/`run`/`include` calls, and follows resolvable links recursively.
Uses the same path resolution rules as the Shiny code viewer
([`resolve_code_path`](https://replicate-anything.github.io/replicateEverything/reference/resolve_code_path.md)).

## Usage

``` r
collect_code_link_issues(study_root, meta)
```

## Arguments

- study_root:

  Absolute study root directory.

- meta:

  Parsed replication metadata.

## Value

Data frame with columns `caller`, `line`, `command`, `path`, `status`,
`message`.
