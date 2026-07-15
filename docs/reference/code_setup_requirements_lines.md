# Human-readable requirement lines for the Code tab setup box

Uses a `study_system_compatibility` audit when supplied; otherwise reads
declared packages from `replication.yml`.

## Usage

``` r
code_setup_requirements_lines(meta, audit = NULL, engines = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- audit:

  Optional compatibility audit from
  [`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md).

- engines:

  Character vector of engines to include (defaults to all declared).
