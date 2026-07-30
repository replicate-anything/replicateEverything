# Whether required Stata SSC packages load without running install scripts

Uses the study's `stata_deps_probe` script when declared; otherwise a
generic `which`-only probe from `stata_packages`. Returns `NA` when
neither is configured (caller should run install scripts or skip per
policy).

## Usage

``` r
stata_dependencies_satisfied(
  study_root,
  staging_dir = NULL,
  timeout = 120L,
  meta = NULL
)
```

## Arguments

- staging_dir:

  Optional writable directory for `$result` output.

- timeout:

  Seconds before aborting (best effort on Windows).

- meta:

  Parsed replication metadata.

## Value

`TRUE`, `FALSE`, or `NA` (no probe configured), with `stata_executable`
/ `stata_label` / `missing` attributes.

## Details

The returned logical carries diagnostic attributes so callers can report
precisely *which* Stata was used and *which* package(s) actually failed,
instead of blaming every declared package for one broken probe (the
`moremata` bug): `stata_executable` (path), `stata_label`
(human-readable), and `missing` (character vector - the specific package
attributed to the failure when derivable, else all declared packages as
a conservative fallback).
