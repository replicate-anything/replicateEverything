# Relay per-package `REPLICATE_DEP_STATUS:` lines from an install log

[`stata_deps_install_lines_from_packages()`](https://replicate-anything.github.io/replicateEverything/reference/stata_deps_install_lines_from_packages.md)
prints one `REPLICATE_DEP_STATUS: ...` line per declared package
(already present / installed) so the install can report success/failure
without the caller having to open the Stata batch log by hand.

## Usage

``` r
stata_install_status_lines(log_path)
```

## Arguments

- log_path:

  Path to a Stata batch log written by the install runner.

## Value

Character vector of status lines (without the marker prefix), or
`character(0)` when the log has none (e.g. custom install script).
