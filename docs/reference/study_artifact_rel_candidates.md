# Candidate display artifact paths under `outputs/`

Uses displayable paths from `outputs:` (html/png/rds/svg/xlsx/csv/dta),
then declared prep sinks (including `.done`), then type-based defaults
under `outputs/`. Prep steps with declared sinks skip the misleading
`outputs/<id>.html`/`.png` fallbacks that produced remote HTTP 404s.

## Usage

``` r
study_artifact_rel_candidates(rep)
```

## Arguments

- rep:

  A single replication entry from `replication.yml`.
