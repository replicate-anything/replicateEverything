# Snapshot identity of declared Stata output candidates before a run

Used so a successful-looking Stata exit cannot silently reuse a stale
pre-existing output when the do-file never rewrote it (e.g. an unclosed
`/*` block comment swallowed the script).

## Usage

``` r
stata_output_mtime_snapshot(rep, study_root, staging_dir = NULL)
```
