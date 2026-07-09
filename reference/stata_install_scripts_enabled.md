# Whether study Stata install scripts may run (maintainer / build only)

Live Run and Shiny probe dependencies only. Set
`options(replicateEverything.install_stata_deps = TRUE)` to allow
`install_stata_deps.do` (e.g.
`build_study_artifacts(install_deps = TRUE)`).

## Usage

``` r
stata_install_scripts_enabled()
```
