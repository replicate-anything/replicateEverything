# Check that claimed steps have Display sinks Shiny can show without errors

Tables/figures need baked html/png. Pattern B Dataverse access steps
need resolvable file-id wiring (Display uses a yaml summary; binary may
be gitignored). Other transform steps with displayable `outputs:`
(html/png/rds/svg) must have those files on disk. Inherited steps are
checked against the parent study root (or pass when the parent is not
local) — extensions must not commit parent prep sinks.

## Usage

``` r
check_display_sink_rows(meta, study_root)
```

## Arguments

- meta:

  Parsed replication.yml.

- study_root:

  Local study or package root.

## Value

Data frame of check rows (same shape as
[`check_result()`](https://replicate-anything.github.io/replicateEverything/reference/check_result.md)
binds).
